import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();

/**
 * Retourne une chaîne nettoyée ou une valeur par défaut.
 * @param {unknown} value Valeur à convertir.
 * @param {string} fallback Valeur de secours si vide.
 * @return {string} Texte nettoyé.
 */
function cleanText(value: unknown, fallback: string): string {
  const s = String(value ?? "").trim();
  return s.length === 0 ? fallback : s;
}


/**
 * Notification lors d'un ajout d'événement agenda.
 */
export const agendaNotification = onDocumentCreated(
  "events/{eventId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title = cleanText(data.title, "Nouvel événement agenda");
    const body = cleanText(
      data.description,
      "Un nouvel événement a été ajouté."
    );

    await getMessaging().send({
      topic: "utilisateurs",
      notification: {
        title: "Agenda",
        body: title,
      },
      data: {
        type: "agenda",
        title,
        body,
      },
    });
  }
);

/**
 * Notification lors d'activation ou modification d'un message épinglé.
 */
export const pinnedMessageNotification = onDocumentUpdated(
  "app_settings/pinned_message",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasActive = before.isActive === true;
    const isActive = after.isActive === true;

    const beforeTitle = String(before.title ?? "").trim();
    const afterTitle = String(after.title ?? "").trim();
    const beforeBody = String(before.body ?? "").trim();
    const afterBody = String(after.body ?? "").trim();

    const activatedNow = !wasActive && isActive;
    const changedWhileActive = isActive &&
      (beforeTitle !== afterTitle || beforeBody !== afterBody);

    if (!activatedNow && !changedWhileActive) {
      return;
    }

    const notifTitle = afterTitle.length > 0 ?
      afterTitle :
      "Message important";

    const notifBody = afterBody.length > 0 ?
      afterBody :
      "Un message épinglé a été publié.";

    await getMessaging().send({
      topic: "utilisateurs",
      notification: {
        title: "Message important",
        body: notifTitle,
      },
      data: {
        type: "pinned_message",
        title: notifTitle,
        body: notifBody,
      },
    });
  }
);

/**
 * Notification lors d'une réservation mobil-home.
 */
export const mobilhomeReservationNotification = onDocumentCreated(
  "mobilhome_reservations/{reservationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;

    const name = cleanText(
      record["fullName"] ?? record["name"],
      "Réservation mobil-home"
    );
    const start = cleanText(record["startDate"], "");
    const end = cleanText(record["endDate"], "");

    const body = start.length > 0 && end.length > 0 ?
      `${name} a réservé du ${start} au ${end}.` :
      `${name} a effectué une réservation.`;

    await getMessaging().send({
      topic: "mobilhommes",
      notification: {
        title: "Nouvelle réservation mobil-home",
        body,
      },
      data: {
        type: "mobilhome_reservation",
      },
    });
  }
);

/**
 * Notification lors d'un formulaire véhicule complété.
 */
export const vehicleCheckNotification = onDocumentCreated(
  "vehicle_checks_submissions/{submissionId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;
    const formTitle = cleanText(record["formTitle"], "Contrôle véhicule");
    const fullName = cleanText(record["fullName"], "Un utilisateur");

    await getMessaging().send({
      topic: "mecano",
      notification: {
        title: "Formulaire véhicule complété",
        body: `${formTitle} complété par ${fullName}.`,
      },
      data: {
        type: "vehicle_check",
        formTitle,
      },
    });
  }
);


export const ticketNotification = onDocumentCreated(
  "tickets/{ticketId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;
    const type = cleanText(record["type"], "Ticket");
    const title = cleanText(record["title"], "Nouveau ticket");
    const createdByEmail = cleanText(record["createdByEmail"], "Utilisateur inconnu");

    await getMessaging().send({
      topic: "admins",
      notification: {
        title: `Nouveau ${type.toLowerCase()}`,
        body: `${title} • ${createdByEmail}`,
      },
      data: {
        type: "ticket",
        ticketType: type,
        ticketTitle: title,
      },
    });
  }
);

/**
 * Notification lors d'un retour inter VSAV complété.
 */
export const vsavReturnNotification = onDocumentCreated(
  "vsav_return_submissions/{submissionId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;
    const fullName = cleanText(record["fullName"], "Un utilisateur");
    const interventionNumber = cleanText(record["interventionNumber"], "");

    const body = interventionNumber.length > 0 ?
      `Retour Inter VSAV n°${interventionNumber} complété par ${fullName}.` :
      `Retour Inter VSAV complété par ${fullName}.`;

    await getMessaging().send({
      topic: "suap",
      notification: {
        title: "Retour Inter VSAV complété",
        body,
      },
      data: {
        type: "vsav_return",
      },
    });
  }
);

/**
 * Notification lors d'un sac prompt secours complété.
 */
export const promptSecoursNotification = onDocumentCreated(
  "prompt_secours_submissions/{submissionId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;
    const fullName = cleanText(record["fullName"], "Un utilisateur");
    const interventionNumber = cleanText(record["interventionNumber"], "");

    const body = interventionNumber.length > 0 ?
      `Sac Prompt Secours n°${interventionNumber} complété par ${fullName}.` :
      `Sac Prompt Secours complété par ${fullName}.`;

    await getMessaging().send({
      topic: "suap",
      notification: {
        title: "Sac Prompt Secours complété",
        body,
      },
      data: {
        type: "prompt_secours",
      },
    });
  }
);
