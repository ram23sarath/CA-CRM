import { z } from "zod";

export const emailSchema = z.string().trim().email("Enter a valid email address.");
export const passwordSchema = z.string().min(8, "Use at least 8 characters.").regex(/[A-Za-z]/, "Use at least one letter.").regex(/[0-9]/, "Use at least one number.");
export const mobileSchema = z.string().regex(/^\+91[6-9][0-9]{9}$/, "Use an Indian mobile number such as +919876543210.");

export const signupSchema = z.object({
  firmName: z.string().trim().min(1, "Firm name is required.").max(160, "Firm name is too long."),
  fullName: z.string().trim().min(1, "Full name is required.").max(160, "Full name is too long."),
  email: emailSchema,
  mobileNumber: mobileSchema,
  password: passwordSchema,
  confirmPassword: z.string(),
}).refine((values) => values.password === values.confirmPassword, { path: ["confirmPassword"], message: "Passwords do not match." });

export const loginSchema = z.object({ email: emailSchema, password: z.string().min(1, "Password is required.") });

export function validationErrors(error: z.ZodError) {
  return error.flatten().fieldErrors;
}
