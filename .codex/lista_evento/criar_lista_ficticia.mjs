import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "L:/Scripts/app_casamento/saida_simulacao_evento";
await fs.mkdir(outputDir, { recursive: true });

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Lista de Convidados");
sheet.showGridLines = false;

sheet.mergeCells("A1:D1");
sheet.getRange("A1").values = [["Casamento Jardim das Oliveiras — Lista Fictícia"]];
sheet.mergeCells("A2:D2");
sheet.getRange("A2").values = [["Simulação de evento | 4 mesas | 20 convidados"]];
sheet.getRange("A4:D4").values = [["Mesa", "Convidado", "Categoria", "Observação"]];

const rows = [
  [1, "Ana Clara Souza", "Família", ""],
  [1, "Bruno Souza", "Família", ""],
  [1, "Carolina Souza", "Família", "Vegetariana"],
  [1, "Daniel Souza", "Família", ""],
  [1, "Helena Souza", "Família", "Criança"],
  [2, "Isabela Martins", "Amigos", ""],
  [2, "João Martins", "Amigos", ""],
  [2, "Larissa Lima", "Amigos", "Sem álcool"],
  [2, "Marcos Lima", "Amigos", ""],
  [2, "Nathalia Lima", "Amigos", ""],
  [3, "Otávio Pereira", "Trabalho", ""],
  [3, "Paula Pereira", "Trabalho", ""],
  [3, "Rafael Costa", "Trabalho", "Acessibilidade"],
  [3, "Sabrina Costa", "Trabalho", ""],
  [3, "Tiago Costa", "Trabalho", ""],
  [4, "Ursula Almeida", "Família", ""],
  [4, "Victor Almeida", "Família", ""],
  [4, "Wesley Rocha", "Família", ""],
  [4, "Yasmin Rocha", "Família", ""],
  [4, "Zeca Rocha", "Família", "Criança"],
];
sheet.getRange("A5:D24").values = rows;

sheet.getRange("A1:D1").format = {
  fill: "#5B3A86",
  font: { bold: true, color: "#FFFFFF", size: 16 },
  horizontalAlignment: "Center",
  verticalAlignment: "Center",
};
sheet.getRange("A2:D2").format = {
  fill: "#EEE7F7",
  font: { italic: true, color: "#4A3A5E" },
  horizontalAlignment: "Center",
};
sheet.getRange("A4:D4").format = {
  fill: "#DCCCF0",
  font: { bold: true, color: "#2E1A47" },
  horizontalAlignment: "Center",
  verticalAlignment: "Center",
  borders: { preset: "outside", style: "medium", color: "#8D6BB8" },
};
sheet.getRange("A5:D24").format = {
  font: { color: "#25212B" },
  verticalAlignment: "Center",
  borders: { insideHorizontal: { style: "thin", color: "#E5DDED" } },
};
sheet.getRange("A5:A24").format.horizontalAlignment = "Center";
sheet.getRange("A5:A24").format.numberFormat = "0";
sheet.getRange("A1:D24").format.wrapText = true;
sheet.getRange("A1:D1").format.rowHeight = 30;
sheet.getRange("A2:D2").format.rowHeight = 22;
sheet.getRange("A4:D4").format.rowHeight = 24;
sheet.getRange("A:A").format.columnWidth = 10;
sheet.getRange("B:B").format.columnWidth = 28;
sheet.getRange("C:C").format.columnWidth = 16;
sheet.getRange("D:D").format.columnWidth = 22;
sheet.freezePanes.freezeRows(4);

const table = sheet.tables.add("A4:D24", true, "ListaConvidadosFicticia");
table.style = "TableStyleMedium2";
table.showFilterButton = true;

const summary = workbook.worksheets.add("Resumo");
summary.showGridLines = false;
summary.mergeCells("A1:C1");
summary.getRange("A1").values = [["Resumo da lista fictícia"]];
summary.getRange("A3:C7").values = [
  ["Indicador", "Valor", "Observação"],
  ["Mesas", 4, "Mesas numeradas de 1 a 4"],
  ["Convidados", 20, "Cinco convidados por mesa"],
  ["Com observação", 6, "Restrições, acessibilidade ou faixa etária"],
  ["Arquivo", "lista_evento_ficticia.xlsx", "Criado para esta simulação"],
];
summary.getRange("A1:C1").format = { fill: "#5B3A86", font: { bold: true, color: "#FFFFFF", size: 16 }, horizontalAlignment: "Center" };
summary.getRange("A3:C3").format = { fill: "#DCCCF0", font: { bold: true, color: "#2E1A47" }, horizontalAlignment: "Center" };
summary.getRange("A4:C7").format = { borders: { insideHorizontal: { style: "thin", color: "#E5DDED" } } };
summary.getRange("A:A").format.columnWidth = 20;
summary.getRange("B:B").format.columnWidth = 28;
summary.getRange("C:C").format.columnWidth = 34;

const inspect = await workbook.inspect({ kind: "table", range: "'Lista de Convidados'!A1:D24", include: "values,formulas", tableMaxRows: 6, tableMaxCols: 4, maxChars: 3000 });
console.log(inspect.ndjson);
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 50 }, summary: "formula error scan" });
console.log(errors.ndjson);
const preview = await workbook.render({ sheetName: "Lista de Convidados", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile(`${outputDir}/lista_evento_ficticia.png`, new Uint8Array(await preview.arrayBuffer()));
const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(`${outputDir}/lista_evento_ficticia.xlsx`);
console.log(`EXPORT_OK:${outputDir}/lista_evento_ficticia.xlsx`);
