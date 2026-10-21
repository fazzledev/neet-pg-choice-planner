import json
from html import escape
from pathlib import Path

root = Path(__file__).resolve().parents[2]
catalog = json.loads((root / "data/available_choices.json").read_text())
institutes = {institute["code"]: institute["name"] for institute in catalog["institutes"]}
general_medicine = {choice["instcd"]: choice for choice in catalog["choices"] if choice["quota"] == "All India" and choice["program"] == "M.D. General Medicine"}

plan_codes = ["700357", "700360", "700391", "700363", "700340", "700301", "700385", "700296"]
filled_codes = ["700360", "700357", "700391", "701506", "700340", "700363", "700398"]
available_codes = plan_codes + ["701506", "700398", "700475", "700308", "700416", "700297"]


def choice(code):
    entry = general_medicine[code]
    return {"instcd": code, "brcd": entry["brcd"], "quota": entry["quota"], "institute": institutes[code], "program": entry["program"]}


def row(code, buttons):
    c = choice(code)
    cells = [c["instcd"], c["institute"], c["brcd"], c["program"], "Government", c["quota"]]
    return "<tr>" + "".join(f"<td>{escape(cell)}</td>" for cell in cells) + f"<td>{buttons}</td></tr>"


order = {
    "counselling": catalog["counselling"],
    "owner": None,
    "sentAt": "2026-10-21T10:30:00+05:30",
    "choices": [{"rank": rank, **choice(code)} for rank, code in enumerate(plan_codes, start=1)],
}

header = "<tr><th>Code</th><th>Institute</th><th>Course code</th><th>Course</th><th>Type</th><th>Quota</th><th></th></tr>"
filled_rows = "".join(row(code, '<button class="Up">Up</button> <button class="fChoice">Remove</button>') for code in filled_codes)
available_rows = "".join(row(code, '<button class="aChoice">Add</button>') for code in available_codes if code not in filled_codes)

page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Choice filling (sample)</title>
<style>
  body {{ margin: 0; font: 13px/1.4 system-ui, sans-serif; color: #1d2433; background: #eef1f6; }}
  header {{ padding: 14px 24px; background: #fff; border-bottom: 1px solid #d9dee8; font-weight: 600; font-size: 15px; }}
  main {{ padding: 16px 24px; display: grid; gap: 16px; max-width: 860px; }}
  section {{ background: #fff; border: 1px solid #d9dee8; border-radius: 8px; overflow: hidden; }}
  h2 {{ margin: 0; padding: 10px 12px; font-size: 13px; background: #f6f7fa; border-bottom: 1px solid #d9dee8; }}
  table {{ width: 100%; border-collapse: collapse; }}
  th, td {{ padding: 6px 10px; text-align: left; border-bottom: 1px solid #eef0f4; vertical-align: top; }}
  th {{ font-weight: 600; color: #5b6475; font-size: 12px; }}
  td:nth-child(3), td:nth-child(5), th:nth-child(3), th:nth-child(5) {{ display: none; }}
  button {{ font: inherit; font-size: 12px; padding: 2px 8px; border: 1px solid #c3c9d6; border-radius: 4px; background: #fff; }}
</style>
<script>
  const sampleOrder = {json.dumps(order)}
  const store = {{ order: sampleOrder }}
  globalThis.chrome = {{
    runtime: {{ id: "sample", getURL: (path) => `chrome-extension://sample/${{path}}` }},
    storage: {{
      local: {{
        get: async (key) => ({{ [key]: store[key] }}),
        set: async (values) => Object.assign(store, values),
        remove: async (key) => {{ delete store[key] }},
      }},
      onChanged: {{ addListener() {{}} }},
    }},
  }}
</script>
</head>
<body>
<header>Choice filling · sample page with made-up choices</header>
<main>
  <section><h2>Filled choices</h2><table id="filledChoiceContainer">{header}{filled_rows}</table></section>
  <section><h2>Available choices</h2><table id="avlChoiceContainer">{header}{available_rows}</table></section>
</main>
<script>
  const filledTable = document.querySelector("#filledChoiceContainer")
  const availableTable = document.querySelector("#avlChoiceContainer")
  const actionCell = (row) => row.cells[row.cells.length - 1]
  document.addEventListener("click", (event) => {{
    const button = event.target.closest("main button")
    if (!button) return
    const row = button.closest("tr")
    if (button.classList.contains("aChoice")) {{
      actionCell(row).innerHTML = '<button class="Up">Up</button> <button class="fChoice">Remove</button>'
      filledTable.append(row)
    }}
    if (button.classList.contains("fChoice")) {{
      actionCell(row).innerHTML = '<button class="aChoice">Add</button>'
      availableTable.append(row)
    }}
    if (button.classList.contains("Up") && row.previousElementSibling?.querySelector("td")) row.after(row.previousElementSibling)
  }})
</script>
<script src="../../extension/portal-adapter.js"></script>
<script src="../../extension/portal.js"></script>
<script>
  const panel = () => document.querySelector("#choice-planner-filler").shadowRoot
  const scenes = {{
    differences: () => panel().querySelector("details")?.setAttribute("open", ""),
    synced: () => {{
      panel().querySelector('[data-action="to-mcc"]').click()
      setTimeout(() => panel().querySelector('[data-action="confirm"]')?.click(), 100)
    }},
  }}
  setTimeout(() => scenes[location.hash.slice(1)]?.(), 400)
</script>
</body>
</html>
"""

(Path(__file__).parent / "sample-portal.html").write_text(page)
