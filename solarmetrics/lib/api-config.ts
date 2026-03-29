/**
 * URL base da API Spring Boot (Java). Em Static Web Apps use NEXT_PUBLIC_API_URL=https://seu-app-java.azurewebsites.net
 */
export function getApiBaseUrl(): string {
  const raw = process.env.NEXT_PUBLIC_API_URL ?? ""
  return raw.replace(/\/$/, "")
}
