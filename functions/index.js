/**
 * Cloud Functions de TrainApp.
 *
 * Desplegar:  firebase deploy --only functions --project trainapp-prod
 *
 * Secretos (una vez):
 *   firebase functions:secrets:set GMAIL_APP_PASSWORD --project trainapp-prod
 *   → contraseña de aplicación de Google de trainappdev@gmail.com
 *     (https://myaccount.google.com/apppasswords, requiere verificación en 2 pasos).
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { defineSecret }      = require('firebase-functions/params');
const logger                = require('firebase-functions/logger');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { initializeApp }     = require('firebase-admin/app');
const { getAuth }           = require('firebase-admin/auth');
const nodemailer            = require('nodemailer');
const classes               = require('./classes');
const premium               = require('./premium');

// La base `trainapp` está en southamerica-east1: los triggers de Firestore
// deben correr en la misma región.
const REGION      = 'southamerica-east1';
const DATABASE_ID = 'trainapp';

const ADMIN_EMAIL = 'trainappdev@gmail.com';
const PORTAL_URL  = 'https://trainapp-prod.web.app/gimnasio';

const GMAIL_APP_PASSWORD = defineSecret('GMAIL_APP_PASSWORD');

const app = initializeApp();
const db  = () => classes.getFirestore(app, DATABASE_ID);

const escapeHtml = s =>
  String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/**
 * Avisa por correo al admin cuando llega una solicitud de alta de gimnasio:
 * al crearla y al reenviarla tras un rechazo. Las ediciones de una solicitud
 * que ya estaba pendiente, y las aprobaciones/rechazos, no generan correo.
 */
exports.notifyGymRequest = onDocumentWritten(
  {
    document: 'gym_requests/{uid}',
    database: DATABASE_ID,
    region: REGION,
    secrets: [GMAIL_APP_PASSWORD],
  },
  async event => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!after || after.status !== 'pending') return;
    if (before && before.status === 'pending') return;

    const resubmitted = before?.status === 'rejected';
    const rows = [
      ['Gimnasio', after.gymName],
      ['Contacto', after.contactName],
      ['Email', after.email],
      ['Teléfono', after.phone],
      ['Ciudad', after.city],
      ['Dirección', after.address],
      ['Página web', after.websiteUrl || '—'],
    ];

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: ADMIN_EMAIL, pass: GMAIL_APP_PASSWORD.value() },
    });

    try {
      await transporter.sendMail({
        from: `TrainApp <${ADMIN_EMAIL}>`,
        to: ADMIN_EMAIL,
        replyTo: after.email || undefined,
        subject: `${resubmitted ? 'Solicitud reenviada' : 'Nueva solicitud'} de gimnasio: ${after.gymName}`,
        text:
          rows.map(([k, v]) => `${k}: ${v ?? ''}`).join('\n') +
          `\n\nRevísala en ${PORTAL_URL} → Solicitudes.`,
        html: `
          <h2 style="font-family:sans-serif">${resubmitted ? 'Solicitud reenviada' : 'Nueva solicitud'} de gimnasio</h2>
          <table style="font-family:sans-serif;border-collapse:collapse">
            ${rows.map(([k, v]) => `
              <tr>
                <td style="padding:4px 16px 4px 0;color:#666">${k}</td>
                <td style="padding:4px 0"><b>${escapeHtml(v)}</b></td>
              </tr>`).join('')}
          </table>
          <p style="font-family:sans-serif">
            <a href="${PORTAL_URL}">Abrir el portal</a> → Solicitudes para aprobarla o rechazarla.
          </p>`,
      });
      logger.info('Correo de solicitud enviado', { uid: event.params.uid, gym: after.gymName });
    } catch (err) {
      // No se reintenta: la solicitud igual queda visible en el portal.
      logger.error('No se pudo enviar el correo de solicitud', { uid: event.params.uid, err: err.message });
    }
  },
);

/**
 * Clases grupales: al crear, editar o borrar un horario semanal, ajusta sus
 * clases de los próximos 14 días (ver `classes.js`).
 */
exports.syncGymSchedule = onDocumentWritten(
  {
    document: 'gyms/{gymId}/schedules/{scheduleId}',
    database: DATABASE_ID,
    region: REGION,
  },
  async event => {
    const { gymId, scheduleId } = event.params;
    const schedule = event.data?.after?.data() ?? null;
    const counts = await classes.syncSchedule(db(), gymId, scheduleId, schedule);
    logger.info('Horario sincronizado', { gymId, scheduleId, ...counts });
  },
);

/**
 * Clases grupales: cada madrugada (hora de Bogotá) genera el día nuevo que
 * entra en la ventana de 14 días para todos los horarios activos.
 */
exports.generateGymClasses = onSchedule(
  {
    schedule: 'every day 03:00',
    timeZone: 'America/Bogota',
    region: REGION,
  },
  async () => {
    const created = await classes.syncAllSchedules(db());
    logger.info('Clases generadas', { created });
  },
);

/**
 * Premium: al invitar, aceptar, retirar o cambiar el premium de un miembro
 * del gimnasio, recalcula su `entitlements/{uid}` y su periodo facturable
 * (ver `premium.js`).
 */
exports.syncMemberEntitlement = onDocumentWritten(
  {
    document: 'gym_members/{uid}',
    database: DATABASE_ID,
    region: REGION,
  },
  async event => {
    const result = await premium.recomputeEntitlement(db(), event.params.uid);
    if (result.changed) logger.info('Premium actualizado', result);
  },
);

/**
 * Premium: al crear un gimnasio, cambiar su dueño o suspenderlo/reactivarlo,
 * recalcula al dueño y a todos sus miembros.
 */
exports.syncGymEntitlements = onDocumentWritten(
  {
    document: 'gyms/{gymId}',
    database: DATABASE_ID,
    region: REGION,
  },
  async event => {
    const before = event.data?.before?.data() ?? null;
    const after  = event.data?.after?.data() ?? null;
    const statusChanged = (before?.status ?? 'active') !== (after?.status ?? 'active');
    const ownerChanged  = before?.ownerUid !== after?.ownerUid;
    if (!statusChanged && !ownerChanged) return;

    const owners = [before?.ownerUid, after?.ownerUid];
    const results = statusChanged
      ? await premium.recomputeGym(db(), event.params.gymId, owners)
      : await Promise.all(owners.filter(Boolean)
          .map(uid => premium.recomputeEntitlement(db(), uid)));
    logger.info('Premium del gimnasio recalculado', {
      gymId: event.params.gymId,
      changed: results.filter(r => r.changed).length,
    });
  },
);

/**
 * Prueba gratis: al crear `trial_requests/{uid}` la activa (o la rechaza si
 * el email ya la usó); al borrarla (p. ej. al eliminar la cuenta) recalcula.
 */
exports.startTrial = onDocumentWritten(
  {
    document: 'trial_requests/{uid}',
    database: DATABASE_ID,
    region: REGION,
  },
  async event => {
    const uid = event.params.uid;
    const after = event.data?.after?.data() ?? null;
    if (!after) {
      await premium.recomputeEntitlement(db(), uid);
      return;
    }
    if (after.status) return; // ya procesada (la escribió esta misma función)
    let email = null;
    try {
      email = (await getAuth(app).getUser(uid)).email ?? null;
    } catch (err) {
      logger.warn('Prueba gratis: usuario no encontrado', { uid, err: err.message });
    }
    const result = await premium.startTrial(db(), uid, email);
    logger.info('Prueba gratis', result);
  },
);

/** Prueba gratis: cada hora cierra las pruebas vencidas. */
exports.expireTrials = onSchedule(
  {
    schedule: '0 * * * *',
    timeZone: 'America/Bogota',
    region: REGION,
  },
  async () => {
    const expired = await premium.expireTrials(db());
    if (expired) logger.info('Pruebas vencidas', { expired });
  },
);

/**
 * Facturación: el día 1 de cada mes (hora de Bogotá) genera la factura del
 * mes anterior de cada gimnasio con atletas premium cobrables.
 */
exports.generateGymInvoices = onSchedule(
  {
    schedule: '30 0 1 * *',
    timeZone: 'America/Bogota',
    region: REGION,
  },
  async () => {
    const { year, month0 } = premium.previousMonth(new Date());
    const created = await premium.generateInvoices(db(), year, month0);
    logger.info('Facturas generadas', { month: premium.monthId(year, month0), created });
  },
);
