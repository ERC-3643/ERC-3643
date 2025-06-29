const fs = require("fs");
const path = require("path");

// ========== INPUTS ==========

const oldData = JSON.parse(process.argv[2]);
const newData = JSON.parse(process.argv[3]);
const contractPath = path.parse(process.argv[4]);
const omitNew = process.argv[5];

// Omit if same
if (JSON.stringify(oldData) === JSON.stringify(newData)) process.exit(0);

// ========== VISUALIZE LAYOUTS ==========

const oldVisualized = createLayout(oldData);
//console.log(JSON.stringify(oldVisualized, null, 2));

const newVisualized = createLayout(newData);
//console.log(JSON.stringify(newVisualized, null, 2));

const overlayedVisualized = overlayLayouts(oldVisualized, newVisualized);
//console.log(JSON.stringify(overlayedVisualized, null, 2));

const [alignedOverlayedVisualized, alignedOldVisualized] = alignLayouts(overlayedVisualized, oldVisualized);
//console.log(JSON.stringify(alignedOverlayedVisualized, null, 2));
//console.log(JSON.stringify(alignedOldVisualized, null, 2));

if (alignedOldVisualized.length !== alignedOverlayedVisualized.length) {
  console.warn(
    "Error: Lengths do not match.\nThis is a bug. Please, submit a new issue: https://github.com/0xPolygon/storage-delta/issues.",
  );
  process.exit(1);
}

// ========== ANALYZE ==========

let reportOld = "";
let reportNew = "";
let i = 0;

for (; i < alignedOldVisualized.length; i++) {
  const oldItem = alignedOldVisualized[i];
  const overlayedItem = alignedOverlayedVisualized[i];

  // overlayedItem can be undefined, dirty, or a storage item
  // oldItem can be undefined or a storage item

  // Emojis:
  // 🏴 - Problematic
  // 🏳️ - Moved
  // 🏁 - Moved & problematic
  // 🪦 - Removed
  // 🌱 - New

  // Same start
  if (checkStart(overlayedItem, oldItem) === 1) {
    // auto
    if (overlayedItem.label === "@dirty") {
      printNew(false, "🪦");
      printOld(true);
      continue;
    }
    if (!isSame(overlayedItem, oldItem)) {
      if (!hasExisted(overlayedItem, oldVisualized)) {
        printNew(true, "🏴");
        printOld(true);
      } else {
        printNew(true, "🏁");
        printOld(true);
      }
    } else {
      printNew(true, "  ");
      printOld(true);
    }
  } else if (checkStart(overlayedItem, oldItem) === 0) {
    if (overlayedItem.label === "@dirty") {
      const diff = overlayedItem.end - overlayedItem.start;
      const s = diff === 1 ? "" : "s";

      const itemLike = {
        ...overlayedItem,
        label: diff + " dirty byte" + s,
        type: {
          label: "",
        },
        offset: overlayedItem.start % 32,
        slot: Math.floor(overlayedItem.start / 32),
      };

      reportNew += formatLine("  ", itemLike);
      printOld(false);
      continue;
    }
    if (!isClean(overlayedItem, oldVisualized)) {
      if (!hasExisted(overlayedItem, oldVisualized)) {
        printNew(true, "🏴");
        printOld(false);
      } else {
        printNew(true, "🏁");
        printOld(false);
      }
    } else {
      if (!hasExisted(overlayedItem, oldVisualized)) {
        printNew(true, "🌱");
        printOld(false);
      } else {
        printNew(true, "🏳️");
        printOld(false);
      }
    }
  } else if (checkStart(overlayedItem, oldItem) === -1) {
    // auto
    printNew(false, "🪦");
    printOld(true);
  }
}

// ========== OPTIONS ==========

// --omit report if only New findings
if (!["🏴", "🏳️", "🏁", "🪦"].some((emoji) => reportNew.includes(emoji)) && omitNew) process.exit(1);

// ========== REPORT FINDINGS ==========

// remove \n from end of report
reportOld = reportOld.slice(0, -1);
reportNew = reportNew.slice(0, -1);

const directoryPath = path.join("./storage_delta", contractPath.dir);

// Create directories recursively
try {
  fs.mkdirSync(directoryPath, { recursive: true });
} catch (err) {
  if (err.code !== "EEXIST") throw err;
}

const reportOldPath = path.join(directoryPath, contractPath.name + "-OLD");
const reportNewPath = path.join(directoryPath, contractPath.name + "-NEW");

// Write files
fs.writeFileSync(reportOldPath, reportOld);
fs.writeFileSync(reportNewPath, reportNew);

// ========== HELPERS ==========

// IN: Storage layout JSON
// OUT: Easy to read storage layout JSON
function createLayout(data) {
  const result = [];

  function calcStart(item) {
    let slot = parseInt(item.slot);
    let offset = parseInt(item.offset);
    let result = slot * 32 + offset;
    if (slot + offset === 0) result = 0;
    return result;
  }

  for (const item of data.storage) {
    const start = calcStart(item);
    const end = start + parseInt(data.types[item.type].numberOfBytes);
    const json = {
      label: item.label,
      start: start,
      end: end,
      type: processType(data.types[item.type]),
      slot: item.slot,
      offset: item.offset,
    };
    result.push(json);
  }

  return result;
}

// IN: JSON for "type"
// OUT: JSON of "type" with "astId" and "contract" removed from each "member"
// Note: For shallow comparison. TODO: Deep comparison
function processType(type) {
  if (type && type.members && Array.isArray(type.members)) {
    // Iterate through each member of the type
    type.members.forEach((member) => {
      // Delete the "astId" and "contract" properties from the member
      delete member.astId;
      delete member.contract;
    });
  }
  return type;
}

// IN: Old storage layout JSON, new storage layout JSON
// OUT: New storage layout JSON with dirty bytes visible
function overlayLayouts(oldArray, newArray) {
  let result = [];
  // Create a copy of oldArray to avoid modifying the original
  let oldArrayCopy = oldArray.map((item) => ({ ...item }));
  let oldIndex = 0,
    newIndex = 0;

  while (oldIndex < oldArrayCopy.length || newIndex < newArray.length) {
    let oldItem = oldArrayCopy[oldIndex];
    let newItem = newArray[newIndex];

    if (newItem && (!oldItem || newItem.start < oldItem.start)) {
      // Add the new item and advance the new index
      result.push(newItem);
      newIndex++;
      // Skip over any old items that are completely overlapped by the new item
      while (oldItem && newItem.end >= oldItem.end) {
        oldIndex++;
        oldItem = oldArrayCopy[oldIndex];
      }
    } else if (oldItem) {
      // Handle the case where the old item has no corresponding new item
      if (!newItem || oldItem.end <= newItem.start) {
        result.push({ label: "@dirty", start: oldItem.start, end: oldItem.end });
        oldIndex++;
      } else {
        // Handle partial overlap or complete overlap of the old item by the new item
        if (oldItem.start < newItem.start) {
          result.push({ label: "@dirty", start: oldItem.start, end: newItem.start });
        }

        // Update the old item's start if the new item ends within it
        if (newItem.end < oldItem.end) {
          oldArrayCopy[oldIndex] = { ...oldItem, start: newItem.end };
        } else {
          oldIndex++;
        }
      }
    }
  }

  return result.filter((item) => item.start < item.end);
}

// IN: Overlayed layout, old layout
// OUT: Aligned overlayed layout, aligned old layout
function alignLayouts(layout1, layout2) {
  // Function to insert missing starts from one layout into another
  function insertMissingStarts(baseLayout, referenceLayout) {
    let result = [...baseLayout];
    const referenceStarts = new Set(referenceLayout.map((item) => item.start));

    for (const start of referenceStarts) {
      if (!baseLayout.some((item) => item.start === start)) {
        result.push({ label: "@undefined", start: start });
      }
    }

    // Sort by start to maintain order
    result.sort((a, b) => a.start - b.start);
    return result;
  }

  // Align layout1 with layout2
  let alignedLayout1 = insertMissingStarts(layout1, layout2);

  // Align layout2 with the updated alignedLayout1
  let alignedLayout2 = insertMissingStarts(layout2, alignedLayout1);

  return [alignedLayout1, alignedLayout2];
}

// IN: Storage item, storage item
// OUT: True or false
function isSame(item1, item2) {
  // Compare items by label and type
  if (item1.label === item2.label && JSON.stringify(item1.type) === JSON.stringify(item2.type)) {
    return true; // Items are equal
  } else {
    return false; // Items are not equal
  }
}

// IN: Item from aligned overlayed storage layout, old storage layout
// OUT: True or false
// Note: Check for dirty bytes.
function isClean(item, oldLayout) {
  for (const oldItem of oldLayout) {
    // Check for overlap between the given item and oldItem
    if (item.start < oldItem.end && item.end > oldItem.start) {
      return false; // There is an overlap, not clean
    }
  }
  return true; // No overlaps found, clean
}

// IN: Item from aligned overlayed storage layout, old storage layout
// OUT: True or false
function hasExisted(item, oldLayout) {
  for (const oldItem of oldLayout) {
    if (isSame(item, oldItem)) {
      return true; // The item exists in oldLayout
    }
  }
  return false; // The item does not exist in oldLayout
}

// IN: Item from aligned overlayed storage layout, old storage layout
// OUT: -1 if no start, 0 diff/gt start, 1 if same start
function checkStart(newItem, oldItem) {
  if (newItem.label !== "@undefined" && oldItem.label !== "@undefined") {
    return 1;
  } else if (oldItem.label === "@undefined") {
    return 0;
  } else if (newItem.label === "@undefined") {
    return -1;
  }

  console.warn(
    "Error: Cannot check start.\nThis is a bug. Please, submit a new issue: https://github.com/0xPolygon/storage-delta/issues.",
  );
  process.exit(1);
}

// IN: Whether line should be empty
// Notes: Adds line to old report.
function printOld(notEmpty) {
  if (!notEmpty) reportOld += "\n";
  else reportOld += formatLine("  ", alignedOldVisualized[i]);
}

// IN: Whether line should be empty, finding indicator
// Notes: Adds line to new report.
function printNew(notEmpty, emoji) {
  if (!notEmpty) reportNew += emoji + "\n";
  else reportNew += formatLine(emoji, alignedOverlayedVisualized[i]);
}

// IN: Finding indicator, storage item
function formatLine(emoji, item) {
  emoji = emoji.padEnd(1, " ");
  let slot = item.slot;
  let offset = item.offset.toString().padEnd(5, " ");
  let label = item.label.padEnd(25, " ");
  let type = item.type.label;

  if (item.offset == 0) {
    slot = slot.padEnd(8, " ");
    offset = "";
  } else {
    slot += ": ";
  }

  return `${emoji}  ${slot}${offset}   ${label}    ${type}\n`;
}
