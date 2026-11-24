terraform {
  required_version = ">= 1.4"
}

variable "environment" {
  description = "Nombre del entorno de ejemplo."
  type        = string
  default     = "demo"
}

# terraform_data es un recurso integrado: no requiere proveedores externos,
# así que validate funciona sin credenciales ni descargas.
resource "terraform_data" "example" {
  input = "entorno-${var.environment}"
}

output "example_value" {
  description = "Valor calculado del recurso de ejemplo."
  value       = terraform_data.example.input
}
