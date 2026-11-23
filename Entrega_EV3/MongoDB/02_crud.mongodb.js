use("fazbear_pizza_ev3");

function comprobar(actual, esperado, paso) {
  if (actual !== esperado) throw Error(paso + ": se esperaba " + esperado);
}
function total(pedido) {
  return pedido.items.reduce((suma, i) => suma + i.cantidad * i.precioUnitario, 0);
}

if (!db.getCollectionNames().includes("pedidos")) throw Error("Ejecuta la carga.");
const lotePrueba = ObjectId().toHexString();
const principal = "DEMO-" + lotePrueba;
const filtro = { esPrueba: true, lotePrueba };
const uno = { ...filtro, _id: principal };
const ejemplo = {
  ...uno, fecha: new Date(), estado: "P", notaTemporal: "Borrador",
  cliente: { id: 1, tipo: "VIP" }, local: { id: 1, nombre: "Puerto Montt" },
  items: [{ productoId: 1, nombre: "Pizza Familiar",
    categoria: "PIZZA", cantidad: 1, precioUnitario: 12000 }]
};

try {
  comprobar(db.pedidos.insertOne(ejemplo).insertedId, principal, "Crear");
  const otros = ["-A", "-B"].map(sufijo => ({ ...ejemplo, _id: principal + sufijo }));
  comprobar(Object.keys(db.pedidos.insertMany(otros).insertedIds).length, 2, "Lote");
  printjson({ crear: "OK", individuales: 1, adicionales: 2 });

  const antes = db.pedidos.findOne(uno);
  comprobar(total(antes), 12000, "Total inicial");
  printjson({ leer: "OK", estado: antes.estado, total: total(antes) });

  const cambio = db.pedidos.updateOne({ ...uno, estado: "P" }, {
    $inc: { "items.0.cantidad": 1 }, $set: { estado: "X" }
  });
  comprobar(cambio.modifiedCount, 1, "Actualizar uno");
  const editado = db.pedidos.findOne(uno);
  comprobar(editado.estado, "X", "Estado después del cambio");
  comprobar(total(editado), 24000, "Total actualizado");
  printjson({ actualizar: "OK", estado: editado.estado, total: total(editado) });

  const cancelado = db.pedidos.updateOne({ ...uno, estado: "X" }, {
    $set: { estado: "C" }, $unset: { notaTemporal: "" }
  });
  comprobar(cancelado.modifiedCount, 1, "Cancelar");
  const reactivar = db.pedidos.updateOne({ ...uno, estado: { $in: ["P", "X"] } },
    { $set: { estado: "P" } });
  comprobar(reactivar.matchedCount, 0, "Bloquear reactivación");
  comprobar(db.pedidos.findOne(uno).estado, "C", "Estado cancelado");

  const grupo = { ...filtro, _id: { $in: otros.map(p => p._id) } };
  const varios = db.pedidos.updateMany({ ...grupo, estado: "P" },
    { $set: { estado: "C" }, $unset: { notaTemporal: "" } });
  comprobar(varios.modifiedCount, 2, "Actualizar lote");
  comprobar(db.pedidos.countDocuments({ ...grupo, estado: "C",
    notaTemporal: { $exists: false } }), 2, "Verificar lote y campo temporal");
  printjson({ actualizarLote: "OK", modificados: 2, reactivados: 0 });

  comprobar(db.pedidos.deleteOne({ ...uno, estado: "C" }).deletedCount, 1, "Borrar uno");
  const borrados = db.pedidos.deleteMany({ ...grupo, estado: "C" });
  comprobar(borrados.deletedCount, 2, "Borrar lote");
  const restantes = db.pedidos.countDocuments(filtro);
  comprobar(restantes, 0, "Restos del lote de prueba");
  printjson({ borrar: "OK", uno: 1, lote: 2, restantes });
} finally {
  db.pedidos.deleteMany(filtro);
}
