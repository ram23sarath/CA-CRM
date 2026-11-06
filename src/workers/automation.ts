import { nextRetryAt, type AutomationAction, type AutomationChannel } from "@/features/team/automation";

export type DeliveryRequest = {
  deliveryId: string;
  recipientProfileId: string;
  channel: AutomationChannel;
  action: AutomationAction;
  title: string;
  body: string;
  previewOnly: boolean;
};

export type AdapterResult = { status: "PREVIEWED" | "SENT" | "FAILED"; providerReference?: string; error?: string; syntheticEvent?: Record<string, unknown> };

export interface NotificationAdapter {
  readonly channel: AutomationChannel;
  deliver(request: DeliveryRequest): Promise<AdapterResult>;
}

/** Stage 9 adapter: persists a synthetic preview and never opens a network connection. */
export class PreviewNotificationAdapter implements NotificationAdapter {
  constructor(public readonly channel: AutomationChannel) {}
  async deliver(request: DeliveryRequest): Promise<AdapterResult> {
    return { status: "PREVIEWED", syntheticEvent: { deliveryId: request.deliveryId, channel: this.channel, recipientProfileId: request.recipientProfileId, action: request.action, title: request.title, body: request.body } };
  }
}

export function adapterFor(channel: AutomationChannel): NotificationAdapter {
  return new PreviewNotificationAdapter(channel);
}

export function failedDelivery(attempt: number, error: string, maxAttempts: number, now = new Date()) {
  const terminal = attempt >= maxAttempts;
  return { status: terminal ? "DEAD_LETTER" as const : "FAILED" as const, nextAttemptAt: terminal ? null : nextRetryAt(attempt, now), error };
}
