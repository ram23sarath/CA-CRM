import type { ReactNode } from "react";

type DataTableColumn<T> = { key: keyof T; label: string; render?: (row: T) => ReactNode };

export function DataTable<T extends Record<string, unknown>>({ caption, columns, rows, rowKey }: { caption: string; columns: DataTableColumn<T>[]; rows: T[]; rowKey?: (row: T, index: number) => string }) {
  return (
    <div className="table-wrap">
      <table className="data-table">
        <caption>{caption}</caption>
        <thead><tr>{columns.map((column) => <th key={String(column.key)} scope="col">{column.label}</th>)}</tr></thead>
        <tbody>
          {rows.map((row, index) => <tr key={rowKey?.(row, index) ?? index}>{columns.map((column) => <td key={String(column.key)}>{column.render ? column.render(row) : String(row[column.key] ?? "—")}</td>)}</tr>)}
        </tbody>
      </table>
    </div>
  );
}
