use("fazbear_pizza_ev3");

const desde = new Date("2026-11-01T00:00:00-03:00");
const hasta = new Date("2026-12-01T00:00:00-03:00");
const fecha = { $gte: desde, $lt: hasta };
const periodo = { esPrueba: false, fecha };

// Cola del local 1 con pedidos mixtos o de clientes VIP.
const cola = db.pedidos.find({
  ...periodo, "local.id": 1, estado: { $in: ["P", "X"] },
  $or: [
    { "items.categoria": { $all: ["PIZZA", "BEBIDA"] } },
    { "cliente.tipo": "VIP" }
  ]
}, { _id: 0, estado: 1, fecha: 1, "cliente.tipo": 1 })
  .sort({ fecha: -1 }).limit(5).toArray();
printjson({ colaLocal1: cola });
printjson({ tiposCliente: db.pedidos.distinct("cliente.tipo", periodo) });
printjson({ sinTipoCliente: db.pedidos.countDocuments({
  ...periodo, "cliente.tipo": { $exists: false }
}) });

// Subtotal por línea, total por pedido y suma por local.
const totalPedido = { $sum: { $map: {
  input: "$items", as: "item",
  in: { $multiply: ["$$item.cantidad", "$$item.precioUnitario"] }
} } };
const vigentes = { esPrueba: false, estado: { $nin: ["C"] } };
const mensual = db.pedidos.aggregate([
  { $match: { ...vigentes, fecha } },
  { $group: { _id: "$local.id", local: { $first: "$local.nombre" },
    pedidos: { $sum: 1 }, totalClp: { $sum: totalPedido } } },
  { $project: { _id: 0, localId: "$_id", local: 1, pedidos: 1, totalClp: 1 } },
  { $sort: { localId: 1 } }
]).toArray();
const historico = db.pedidos.aggregate([
  { $match: vigentes },
  { $group: { _id: null, totalClp: { $sum: totalPedido } } },
  { $project: { _id: 0, totalClp: 1 } }
]).toArray();
printjson({ mes: "2026-11", resumenPorLocal: mensual,
  totalMesClp: mensual.reduce((suma, l) => suma + l.totalClp, 0),
  totalHistoricoClp: historico[0]?.totalClp ?? 0 });
