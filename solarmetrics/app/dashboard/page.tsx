"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Sun, Plus, Users } from "lucide-react"
import { ClientTable } from "@/components/client-table"
import { ClientDialog } from "@/components/client-dialog"
import type { Cliente } from "@/types/cliente"
import { getApiBaseUrl } from "@/lib/api-config"

export default function DashboardPage() {
  const [clients, setClients] = useState<Cliente[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingClient, setEditingClient] = useState<Cliente | undefined>()

  const fetchClients = async () => {
    try {
      setIsLoading(true)
      const base = getApiBaseUrl()
      const response = await fetch(`${base}/cliente`)
      if (response.ok) {
        const data = await response.json()
        setClients(data)
      }
    } catch (error) {
      console.error("[v0] Error fetching clients:", error)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchClients()
  }, [])

  const handleEdit = (client: Cliente) => {
    setEditingClient(client)
    setIsDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm("Tem certeza que deseja excluir este cliente?")) return

    try {
      const base = getApiBaseUrl()
      const response = await fetch(`${base}/cliente/${id}`, {
        method: "DELETE",
      })
      if (response.ok) {
        fetchClients()
      }
    } catch (error) {
      console.error("[v0] Error deleting client:", error)
    }
  }

  const handleDialogClose = (refresh?: boolean) => {
    setIsDialogOpen(false)
    setEditingClient(undefined)
    if (refresh) {
      fetchClients()
    }
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card">
        <div className="container mx-auto flex items-center justify-between px-4 py-4">
          <Link href="/" className="flex items-center gap-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary">
              <svg width="24" height="24" viewBox="0 0 57 57" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M53.182 15.1541C50.0812 9.32819 45.0724 4.74493 38.9949 2.17216C32.922 -0.357379 26.1568 -0.688514 19.8659 1.23586C13.575 3.16023 8.15284 7.21948 4.53438 12.7136C1.01086 18.1564 -0.532626 24.6458 0.163112 31.0921C0.879221 37.446 3.79856 43.3484 8.41396 47.7737C9.01359 48.3733 9.82908 48.4753 10.2128 48.0615C10.5966 47.6478 10.4407 46.8623 9.89504 46.3226L9.72115 46.1727C5.84587 41.9406 3.53569 36.5097 3.17462 30.7827C2.81355 25.0557 4.42333 19.3777 7.73639 14.6923C10.981 10.1255 15.6881 6.80368 21.0783 5.27704C26.4684 3.75039 32.2183 4.11045 37.3759 6.29758C42.5015 8.50403 46.7212 12.3929 49.3377 17.3219C51.9543 22.2508 52.8112 27.9249 51.7669 33.4067C50.7322 38.7433 47.9741 43.5926 43.9161 47.2096C39.8582 50.8267 34.7249 53.0114 29.3049 53.4282L28.9991 42.407C28.9911 42.1301 28.9237 41.8581 28.8012 41.6095L29.263 41.5736C29.6047 41.5736 29.8626 41.0999 29.8626 40.5422C29.8626 39.9846 29.5987 39.5288 29.263 39.5109H29.167L26.2948 39.307C25.4562 39.2642 24.6282 39.1006 23.8363 38.8213C22.3146 38.2793 20.9847 37.3038 20.0107 36.015C19.0791 34.7652 18.5312 33.2715 18.4337 31.7157C18.4337 31.0381 18.4637 29.9708 18.4877 29.0354V28.2919C24.8197 28.3998 31.1518 28.3758 37.4838 28.2199L37.5798 30.9662C37.6318 32.2798 37.3708 33.5869 36.8182 34.7798C36.217 36.0272 35.3165 37.1064 34.1971 37.9214C33.0776 38.7364 31.774 39.2618 30.4022 39.4509C30.1084 39.5049 29.8686 39.9786 29.8626 40.5422C29.8566 41.1059 30.1504 41.5556 30.5342 41.5736H30.6421C32.479 41.5464 34.2785 41.0507 35.8703 40.1336C37.4622 39.2165 38.7935 37.9083 39.7384 36.3328C40.7055 34.6927 41.2514 32.8387 41.3274 30.9362L41.4893 26.1392C41.5039 25.6211 41.3127 25.1184 40.9577 24.7408C40.6026 24.3633 40.1125 24.1417 39.5945 24.1245H39.4626C37.7956 24.0765 36.1227 24.0765 34.4557 24.0465C35.3121 20.8033 35.0761 17.3682 33.7841 14.2726C33.4486 14.1698 33.0963 14.1332 32.7468 14.1647C32.3993 14.1335 32.049 14.1701 31.7154 14.2726C30.4263 17.3471 30.1819 20.7597 31.0199 23.9865C28.9691 23.9865 26.9184 23.9566 24.8677 23.9865C25.6999 20.7677 25.4578 17.3651 24.1781 14.2966C23.8426 14.1938 23.4903 14.1571 23.1408 14.1887C22.7932 14.1575 22.443 14.1941 22.1094 14.2966C20.8309 17.3656 20.5908 20.7684 21.4258 23.9865C19.7589 23.9865 18.0919 23.9865 16.425 24.0345H16.323C15.7754 24.0487 15.2557 24.2794 14.878 24.6763C14.5003 25.0731 14.2954 25.6035 14.3083 26.1512L14.4102 29.0414C14.4462 30.0188 14.4402 30.8822 14.5601 32.1235C14.8589 34.4152 15.8529 36.5603 17.4084 38.2696C18.939 39.9329 20.9447 41.0844 23.1528 41.5676C24.2123 41.7933 25.2989 41.864 26.3788 41.7774L27.0443 41.7295C26.9539 41.9426 26.9012 42.1699 26.8884 42.4011V42.6289L26.5526 54.9332C26.5438 55.1148 26.5712 55.2962 26.6333 55.467C26.6955 55.6378 26.791 55.7945 26.9144 55.928C27.0378 56.0614 27.1865 56.1689 27.352 56.2442C27.5174 56.3194 27.6962 56.361 27.8778 56.3663H27.9378C34.4008 56.4813 40.7057 54.3634 45.7886 50.3701C50.9407 46.2882 54.5009 40.5314 55.8514 34.0986C57.2019 27.6658 56.2575 20.9632 53.182 15.1541Z" fill="#2A2A2A"/>
                </svg>

            </div>
            <span className="text-xl font-bold text-foreground">SolarMetrics</span>
          </Link>
          <Link href="/">
            <Button variant="outline">Voltar ao Site</Button>
          </Link>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
          <p className="mt-2 text-muted-foreground">Gerencie seus clientes e monitore o sistema</p>
        </div>

        {/* Stats Cards */}
        <div className="mb-8 grid gap-6 md:grid-cols-3">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total de Clientes</CardTitle>
              <Users className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-card-foreground">{clients.length}</div>
              <p className="text-xs text-muted-foreground">Clientes cadastrados</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Residenciais</CardTitle>
              <Sun className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-card-foreground">
                {clients.filter((c) => c.tipoUser === "Residencial").length}
              </div>
              <p className="text-xs text-muted-foreground">Clientes residenciais</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Comerciais</CardTitle>
              <Sun className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-card-foreground">
                {clients.filter((c) => c.tipoUser === "Comercial").length}
              </div>
              <p className="text-xs text-muted-foreground">Clientes comerciais</p>
            </CardContent>
          </Card>
        </div>

        {/* Clients Table */}
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>Clientes</CardTitle>
                <CardDescription>Gerencie todos os seus clientes cadastrados</CardDescription>
              </div>
              <Button onClick={() => setIsDialogOpen(true)}>
                <Plus className="mr-2 h-4 w-4" />
                Novo Cliente
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <ClientTable clients={clients} isLoading={isLoading} onEdit={handleEdit} onDelete={handleDelete} />
          </CardContent>
        </Card>
      </main>

      <ClientDialog open={isDialogOpen} onClose={handleDialogClose} client={editingClient} />
    </div>
  )
}
