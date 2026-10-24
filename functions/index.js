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
const nodemailer            = require('nodemailer');

// La base `trainapp` está en southamerica-east1: los triggers de Firestore
// deben correr en la misma región.
const REGION      = 'southamerica-east1';
const DATABASE_ID = 'trainapp';

const ADMIN_EMAIL = 'trainappdev@gmail.com';
const PORTAL_URL  = 'https://trainapp-prod.web.app/gimnasio';

const GMAIL_APP_PASSWORD = defineSecret('GMAIL_APP_PASSWORD');

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
