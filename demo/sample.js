// Demo 1: start from a native Visual selection and edit every matching fragment.
// 演示 1：从 Neovim 原生 Visual 选区开始，并同步编辑所有匹配内容。
const primaryColor = "#7aa2f7";
const secondaryColor = "#9ece6a";
const borderColor = "#565f89";
console.log(primaryColor, secondaryColor, borderColor);

// Demo 2: add matching words one by one, then insert at every selection.
// 演示 2：逐个添加匹配单词，然后在所有选区中同步插入。
const userName = "alice";
const displayName = userName;
console.log(userName, displayName);

// Demo 3: create vertical cursors and append to every line.
// 演示 3：创建垂直多光标，并在每一行末尾同步追加内容。
let north = "idle";
let south = "idle";
let west = "idle";

// Demo 4: repeatedly expand regions with v, then edit every enclosing call.
// 演示 4：重复按 v 逐级扩大选区，然后同步编辑每个完整调用参数。
const theme = value("dark");
const panel = value("wide");
