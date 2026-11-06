export type ClientStatus = "ACTIVE" | "INACTIVE";
export type EntityType = "INDIVIDUAL" | "COMPANY" | "LLP" | "PARTNERSHIP" | "TRUST" | "OTHER";

export type ClientRecord = { id: string; legal_name: string; display_name: string; entity_type: EntityType; pan: string | null; gstin: string | null; address: string | null; owner_profile_id: string | null; service_tags: string[]; status: ClientStatus; notes: string | null; archived_at: string | null; updated_at: string; created_at: string };
export type ContactRecord = { id: string; full_name: string; email: string | null; phone: string | null; designation: string | null; is_primary: boolean; archived_at: string | null };
export type DocumentRecord = { id: string; file_name: string; mime_type: string | null; byte_size: number | null; created_at: string };
export type MemberOption = { profile_id: string; role: string; profiles: { full_name: string } | null };
