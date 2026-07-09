---@meta

-- Os campos são expostos com a conversão toSnakeCase() aplicada ao nome Zig.
-- Campos do tipo array são retornados como string; campos int como integer.

---Pacote de login enviado pelo cliente (`PacketLoginInput`).
---@class PacketLogin
---@field username   string  Login do usuário (até 16 chars)
---@field password   string  Senha em texto plano (até 12 chars)
---@field version    integer Versão do cliente (ex.: 754)
---@field keys       string  Chaves de sessão (16 bytes)
---@field ip_address  string  IP do cliente (16 bytes)

---Pacote de pin-password enviado pelo cliente (`PacketPinPasswordInput`).
---@class PacketPinPassword
---@field numeric string Sequência de 6 dígitos do PIN

---Pacote de criação de personagem (`PacketCharCreateInput`).
---@class PacketCharCreate
---@field slot  integer Slot escolhido (0-3)
---@field name  string  Nome do personagem (até 16 chars)
---@field class integer Classe: 0=Tk · 1=FM · 2=BM · 3=HT

---Pacote de seleção / entrada no mundo (`PacketEnterWorldInput`).
---@class PacketEnterWorld
---@field char_slot integer Slot do personagem selecionado

---Pacote de movimento/ação (`PacketActionInput`).
---@class PacketAction
---@field speed   integer Velocidade do movimento
---@field kind    integer Tipo de ação
---@field command string  Dados brutos do comando (24 bytes)

---Pacote de movimentação de item no inventário (`PacketMoveItemInput`).
---@class PacketMoveItem
---@field dest_storage   integer Storage de destino
---@field dest_slot      integer Slot de destino
---@field source_storage integer Storage de origem
---@field source_slot    integer Slot de origem

---Pacote de exclusão de personagem (`PacketCharDeleteInput`).
---@class PacketCharDelete
---@field slot     integer Slot do personagem a deletar
---@field name     string  Nome para confirmação (até 16 chars)
---@field password string  Senha para confirmação (até 12 chars)
