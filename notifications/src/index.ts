import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();

function cleanText(value: unknown, fallback: string): string {
  const s = String(value ?? "").trim();
  return s.length === 0 ? fallback : s;
}

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
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);

export const pinnedMessageNotification = onDocumentUpdated(
  "app_settings/pinned_message",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    const wasActive = before.isActive === true;
    const isActive = after.isActive === true;

    const beforeTitle = cleanText(before.title, "");
    const afterTitle = cleanText(after.title, "");
    const beforeBody = cleanText(before.body, "");
    const afterBody = cleanText(after.body, "");

    const activatedNow = !wasActive && isActive;
    const changedWhileActive =
      isActive && (beforeTitle !== afterTitle || beforeBody !== afterBody);

    if (!activatedNow && !changedWhileActive) return;

    const notifTitle = cleanText(after.title, "Message important");
    const notifBody = cleanText(
      after.body,
      "Un message épinglé a été publié."
    );

    await getMessaging().send({
      topic: "utilisateurs",
      notification: {
        title: "Message important",
        body: notifTitle,
      },
      data: {
        type: "pinned_message",
        id: "pinned_message",
        title: notifTitle,
        body: notifBody,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);

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

    const body =
      start.length > 0 && end.length > 0
        ? `${name} a réservé du ${start} au ${end}.`
        : `${name} a effectué une réservation.`;

    await getMessaging().send({
      topic: "mobilhommes",
      notification: {
        title: "Nouvelle réservation mobil-home",
        body,
      },
      data: {
        type: "mobilhome_reservation",
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);

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
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
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
    const createdByEmail = cleanText(
      record["createdByEmail"],
      "Utilisateur inconnu"
    );

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
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);

export const vsavReturnNotification = onDocumentCreated(
  "vsav_return_submissions/{submissionId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;
    const fullName = cleanText(record["fullName"], "Un utilisateur");
    const interventionNumber = cleanText(record["interventionNumber"], "");

    const body =
      interventionNumber.length > 0
        ? `Retour Inter VSAV n°${interventionNumber} complété par ${fullName}.`
        : `Retour Inter VSAV complété par ${fullName}.`;

    await getMessaging().send({
      topic: "suap",
      notification: {
        title: "Retour Inter VSAV complété",
        body,
      },
      data: {
        type: "vsav_return",
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);

export const promptSecoursNotification = onDocumentCreated(
  "prompt_secours_submissions/{submissionId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const record = data as Record<string, unknown>;
    const fullName = cleanText(record["fullName"], "Un utilisateur");
    const interventionNumber = cleanText(record["interventionNumber"], "");

    const body =
      interventionNumber.length > 0
        ? `Sac Prompt Secours n°${interventionNumber} complété par ${fullName}.`
        : `Sac Prompt Secours complété par ${fullName}.`;

    await getMessaging().send({
      topic: "suap",
      notification: {
        title: "Sac Prompt Secours complété",
        body,
      },
      data: {
        type: "prompt_secours",
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  }
);