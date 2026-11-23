use("fazbear_pizza_ev3");

const id = { bsonType: "int", minimum: 1 };
const esquema = {
  bsonType: "object",
  required: ["_id", "fecha", "estado", "esPrueba", "cliente", "local", "items"],
  properties: {
    _id: { bsonType: "string" },
    fecha: { bsonType: "date" },
    estado: { enum: ["P", "X", "E", "C"] },
    esPrueba: { bsonType: "bool" },
    cliente: {
      required: ["id", "tipo"], bsonType: "object",
      properties: { id, tipo: { enum: ["REGULAR", "VIP"] } }
    },
    local: {
      required: ["id", "nombre"], bsonType: "object",
      properties: { id, nombre: { bsonType: "string" } }
    },
    items: {
      bsonType: "array", minItems: 1,
      items: {
        bsonType: "object",
        required: ["productoId", "nombre", "categoria", "cantidad", "precioUnitario"],
        properties: {
          productoId: id, nombre: { bsonType: "string" },
          categoria: { bsonType: "string" }, cantidad: id,
          precioUnitario: { bsonType: "int", minimum: 0 }
        }
      }
    }
  }
};

if (!db.getCollectionNames().includes("pedidos")) {
  db.createCollection("pedidos", { validator: { $jsonSchema: esquema } });
}
db.pedidos.createIndex({ "local.id": 1, estado: 1, fecha: -1 });
db.pedidos.createIndex({ esPrueba: 1, fecha: 1 });

const pizza = [1, "Pizza Familiar", "PIZZA", 12000];
const bebida = [2, "Bebida 350 ml", "BEBIDA", 2000];
const filas = [ // ID, fecha, estado, cliente, local, pizzas y bebidas
  [1, "11-03", "E", 1, 1, 1, 0],
  [2, "11-05", "X", 2, 1, 1, 3],
  [3, "11-07", "C", 1, 1, 2, 0],
  [4, "11-10", "E", 2, 2, 2, 0],
  [5, "11-12", "P", 1, 2, 0, 3],
  [6, "11-15", "P", 1, 1, 1, 0],
  [7, "10-28", "E", 1, 1, 1, 0],
  [8, "12-01", "P", 2, 2, 0, 1]
];
const lote = filas.map(([n, dia, estado, cliente, local, pizzas, bebidas]) => ({
  _id: "EV3-" + n, fecha: new Date("2026-" + dia + "T12:00:00-03:00"),
  estado, esPrueba: false,
  cliente: { id: cliente, tipo: cliente === 1 ? "VIP" : "REGULAR" },
  local: { id: local, nombre: local === 1 ? "Puerto Montt" : "Puerto Varas" },
  items: [[pizza, pizzas], [bebida, bebidas]].filter(([, q]) => q > 0)
    .map(([[productoId, nombre, categoria, precioUnitario], cantidad]) =>
      ({ productoId, nombre, categoria, precioUnitario, cantidad }))
}));
const ids = lote.map(p => p._id);
const existentes = db.pedidos.find({ _id: { $in: ids } }, { _id: 1 }).toArray();
const faltantes = lote.filter(p => !existentes.some(e => e._id === p._id));
if (faltantes.length) db.pedidos.insertMany(faltantes);
printjson({ carga: "OK", insertados: faltantes.length, totalLote: ids.length });
