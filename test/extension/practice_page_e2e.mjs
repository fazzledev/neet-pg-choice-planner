import { spawn } from "node:child_process"
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const baseUrl = process.argv[2] || "http://localhost:3000"
const browserBinary = process.env.CHROMIUM || "chromium"
const productionOrigin = "https://neet-pg-choice-planner.fazzle.dev"
const port = 9300 + Math.floor(Math.random() * 600)
const workDir = mkdtempSync(join(tmpdir(), "practice-e2e-"))
const extensionDir = join(workDir, "extension")
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

cpSync(new URL("../../extension", import.meta.url).pathname, extensionDir, { recursive: true })
const manifestPath = join(extensionDir, "manifest.json")
const localOrigin = new URL(baseUrl).origin.replace(/:\d+$/, "")
writeFileSync(manifestPath, readFileSync(manifestPath, "utf8").replaceAll(productionOrigin, localOrigin))

const browser = spawn(browserBinary, [
  "--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${join(workDir, "profile")}`,
  `--disable-extensions-except=${extensionDir}`, `--load-extension=${extensionDir}`, "--no-first-run", "about:blank",
], { stdio: "ignore" })

async function connect() {
  for (let attempt = 0; attempt < 50; attempt++) {
    try {
      const { webSocketDebuggerUrl } = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json()
      return webSocketDebuggerUrl
    } catch {
      await pause(200)
    }
  }
  throw new Error("Chromium did not start")
}

const socket = new WebSocket(await connect())
await new Promise((resolve) => socket.addEventListener("open", resolve, { once: true }))
let nextId = 0
const pending = new Map()
const contexts = []
socket.addEventListener("message", ({ data }) => {
  const message = JSON.parse(data)
  if (message.id && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id)
    pending.delete(message.id)
    message.error ? reject(new Error(message.error.message)) : resolve(message.result)
  }
  if (message.method === "Runtime.executionContextCreated") contexts.push(message.params.context)
  if (message.method === "Runtime.executionContextsCleared") contexts.length = 0
})
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const id = ++nextId
  pending.set(id, { resolve, reject })
  socket.send(JSON.stringify({ id, method, params, sessionId }))
})

const { targetId } = await send("Target.createTarget", { url: "about:blank" })
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true })
await send("Runtime.enable", {}, sessionId)
await send("Page.enable", {}, sessionId)

async function evaluate(expression, contextId) {
  const { result, exceptionDetails } = await send("Runtime.evaluate", { expression, contextId, awaitPromise: true, returnByValue: true }, sessionId)
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description || exceptionDetails.text)
  return result.value
}

async function waitFor(description, expression, timeout = 20000) {
  for (let waited = 0; waited < timeout; waited += 250) {
    if (await evaluate(expression).catch(() => false)) return
    await pause(250)
  }
  throw new Error(`Timed out waiting for ${description}`)
}

async function openPractice() {
  contexts.length = 0
  await send("Page.navigate", { url: `${baseUrl}/practice` }, sessionId)
  await waitFor("the practice tables", "document.querySelectorAll('#avlChoiceContainer .aChoice').length > 100")
  await waitFor("the extension panel", "Boolean(document.querySelector('#choice-planner-filler')?.shadowRoot?.querySelector('[data-state]')?.textContent)")
}

const panelText = (selector) => evaluate(`document.querySelector('#choice-planner-filler').shadowRoot.querySelector('${selector}').textContent`)
const clickPanel = (action) => evaluate(`document.querySelector('#choice-planner-filler').shadowRoot.querySelector('[data-action="${action}"]').click()`)
const filledKeys = () => evaluate(`[...document.querySelectorAll('#filledChoiceContainer tbody tr')].map((row) => [row.cells[0].textContent, row.cells[2].textContent, row.cells[5].textContent].join('|'))`)
const failures = []
const check = (label, ok, detail = "") => {
  console.log(`${ok ? "ok  " : "FAIL"} ${label}${detail ? ` (${detail})` : ""}`)
  if (!ok) failures.push(label)
}

try {
  await openPractice()
  const catalog = await evaluate(`fetch(document.querySelector('.practice').dataset.catalogUrl).then((response) => response.json())`)
  const institutes = new Map(catalog.institutes.map(([code, name]) => [code, name]))
  const pick = (index) => {
    const [id, instcd, brcd, quota] = catalog.choices[index]
    return { id, instcd, brcd, quota, institute: institutes.get(instcd), program: catalog.programs[brcd]?.[0] || brcd }
  }
  const plan = [40, 7, 300, 12, 1500, 3, 999, 60].map(pick)
  const startingFilled = [3, 12, 77, 7, 5000].map((index) => catalog.choices[index][0])

  const contentScriptContext = contexts.find((context) => context.auxData?.type === "isolated" && context.origin.startsWith("chrome-extension://"))
    || contexts.find((context) => context.auxData?.type === "isolated")
  if (!contentScriptContext) throw new Error("The extension's content script did not run on the practice page")

  const order = { counselling: "practice", owner: null, sentAt: new Date().toISOString(), choices: plan.map(({ id, ...choice }, index) => ({ rank: index + 1, ...choice })) }
  await evaluate(`chrome.storage.local.set(${JSON.stringify({ order })})`, contentScriptContext.id)
  await evaluate(`localStorage.setItem("practice-choice-filling", ${JSON.stringify(JSON.stringify({ filled: startingFilled, locked: false }))})`)

  await openPractice()
  await waitFor("the panel to compare", "/difference/.test(document.querySelector('#choice-planner-filler').shadowRoot.querySelector('[data-state]').textContent)")
  check("panel reports differences before copying", true, await panelText("[data-state]"))

  await clickPanel("to-mcc")
  check("confirmation lists the changes", /add .*remove .*move|add|remove|move/.test(await panelText("[data-confirm-text]")), await panelText("[data-confirm-text]"))
  await clickPanel("confirm")
  await waitFor("Plan → MCC to finish", "/MCC now matches|Stopped/.test(document.querySelector('#choice-planner-filler').shadowRoot.querySelector('[data-message]').textContent)", 60000)
  const finished = await panelText("[data-message]")
  check("Plan → MCC finishes without stopping", finished.startsWith("MCC now matches"), finished)

  const expected = plan.map((choice) => [choice.instcd, choice.brcd, choice.quota].join("|"))
  const actual = await filledKeys()
  check("filled list equals the plan, in order", JSON.stringify(actual) === JSON.stringify(expected), `${actual.length} rows`)

  await waitFor("the panel to show in sync", "/In sync/.test(document.querySelector('#choice-planner-filler').shadowRoot.querySelector('[data-state]').textContent)")
  check("panel shows In sync", true)

  await openPractice()
  check("list survives a reload", JSON.stringify(await filledKeys()) === JSON.stringify(expected))
  check("panel still in sync after reload", /In sync/.test(await panelText("[data-state]")))

  const lockPressed = await evaluate(`(() => { try { PortalAdapter.safeClick(document.querySelector('#btnLockChoices')); return true } catch { return false } })()`, contexts.find((context) => context.auxData?.type === "isolated")?.id)
  check("extension refuses to press Lock choices", lockPressed === false)
} catch (error) {
  failures.push(error.message)
  console.log(`FAIL ${error.message}`)
} finally {
  socket.close()
  browser.kill()
  await pause(300)
  rmSync(workDir, { recursive: true, force: true })
}

console.log(failures.length ? `\n${failures.length} failed` : "\nall passed")
process.exit(failures.length ? 1 : 0)
