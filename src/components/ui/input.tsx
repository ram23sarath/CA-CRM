import type { InputHTMLAttributes } from "react";

type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  hint?: string;
  error?: string;
};

export function Input({ id, label, hint, error, ...props }: InputProps) {
  const inputId = id ?? props.name;
  const hintId = hint ? `${inputId}-hint` : undefined;
  const errorId = error ? `${inputId}-error` : undefined;
  const describedBy = [hintId, errorId].filter(Boolean).join(" ") || undefined;

  return (
    <label className="field" htmlFor={inputId}>
      <span className="field__label">{label}</span>
      <input className="input" id={inputId} aria-describedby={describedBy} aria-invalid={Boolean(error)} {...props} />
      {hint && <span className="field__hint" id={hintId}>{hint}</span>}
      {error && <span className="field__error" id={errorId}>{error}</span>}
    </label>
  );
}
