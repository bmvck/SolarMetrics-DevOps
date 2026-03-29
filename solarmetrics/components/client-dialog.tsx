"use client"

import type React from "react"

import { useState, useEffect } from "react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import type { Cliente } from "@/types/cliente"
import { getApiBaseUrl } from "@/lib/api-config"

interface ClientDialogProps {
  open: boolean
  onClose: (refresh?: boolean) => void
  client?: Cliente
}

export function ClientDialog({ open, onClose, client }: ClientDialogProps) {
  const [formData, setFormData] = useState({
    nome: "",
    email: "",
    telefone: "",
    tipoUser: "Residencial",
  })
  const [isSubmitting, setIsSubmitting] = useState(false)

  useEffect(() => {
    if (client) {
      setFormData({
        nome: client.nome,
        email: client.email || "",
        telefone: client.telefone || "",
        tipoUser: client.tipoUser,
      })
    } else {
      setFormData({
        nome: "",
        email: "",
        telefone: "",
        tipoUser: "Residencial",
      })
    }
  }, [client, open])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)

    try {
      const base = getApiBaseUrl()
      const url = `${base}/cliente`
      const method = client ? "PUT" : "POST"
      const body = client ? JSON.stringify({ id: client.id, ...formData }) : JSON.stringify(formData)

      const response = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json" },
        body,
      })

      if (response.ok) {
        onClose(true)
      } else {
        alert("Erro ao salvar cliente")
      }
    } catch (error) {
      console.error("[v0] Error saving client:", error)
      alert("Erro ao salvar cliente")
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={() => onClose()}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>{client ? "Editar Cliente" : "Novo Cliente"}</DialogTitle>
          <DialogDescription>
            {client ? "Atualize as informações do cliente" : "Adicione um novo cliente ao sistema"}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="nome">Nome</Label>
              <Input
                id="nome"
                value={formData.nome}
                onChange={(e) => setFormData({ ...formData, nome: e.target.value })}
                required
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                required
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="telefone">Telefone</Label>
              <Input
                id="telefone"
                value={formData.telefone}
                onChange={(e) => setFormData({ ...formData, telefone: e.target.value })}
                required
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="tipoUser">Tipo de Cliente</Label>
              <Select
                value={formData.tipoUser}
                onValueChange={(value) => setFormData({ ...formData, tipoUser: value })}
              >
                <SelectTrigger id="tipoUser">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Residencial">Residencial</SelectItem>
                  <SelectItem value="Comercial">Comercial</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onClose()}>
              Cancelar
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Salvando..." : "Salvar"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
