#!/usr/bin/env node
// Codex v0.171.0 experimental MCP status-line protocol. No external packages.
// Mirrors the Claude status line's context/quota thresholds and live Git metrics.
import {spawnSync} from "node:child_process";
import {isAbsolute} from "node:path";
import {createInterface} from "node:readline";

const URI = "ui://app-configs/statusline";
const TOOL = {"name":"statusline","title":"app-configs · Claude-style status line","description":"Display model, project, Git, context and usage in the Codex footer.","inputSchema":{"type":"object","properties":{}},"_meta":{"openai/ui":{"entrypoints":[{"type":"statusline","resourceUri":"ui://app-configs/statusline"}]}}};
function clean(value, max=80) {
  return typeof value==="string" ? value.replace(/[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g,"").slice(0,max) : "";
}

function number(value) { return typeof value==="number" && Number.isFinite(value) && value>=0; }

function short(value) {
  if (!number(value)) return "";
  if (value>=1e6) return `${Number((value/1e6).toFixed(1))}M`;
  if (value>=1e3) return `${Number((value/1e3).toFixed(1))}k`;
  return String(Math.round(value));
}

function color(p,warning=75) { return p>=95?"red":p>=85?"#FF9F43":p>=warning?"yellow":"green"; }

function bar(p) { const n=Math.min(10,Math.max(0,Math.round(p/10)));return "█".repeat(n)+"░".repeat(10-n); }

function segment(value,tone="primary") {return {type:"text",props:{color:tone},children:[value]};}

function row(children,wrap="nowrap") {return {type:"row",props:{gap:1,wrap},children};}

function resetAt(timestamp,now) {
  if (!number(timestamp)||timestamp<=now) return "";
  const minutes=Math.ceil((timestamp-now)/60);
  const days=Math.floor(minutes/1440), hours=Math.floor(minutes%1440/60), mins=minutes%60;
  return days?`${days}d${hours}h`:hours?`${hours}h${mins}m`:`${mins}m`;
}

function parseGit(status,diff) {
  if(typeof status!=="string")return {};
  const items=status.split("\0"), header=items.shift()??"";
  if(!header.startsWith("## "))return {};
  const head=header.slice(3), branch=head.replace(/^No commits yet on |^Initial commit on /,"").split("...")[0];
  let staged=0,unstaged=0,untracked=0;
  for(let i=0;i<items.length;i++){
    const entry=items[i];if(entry.length<3)continue;
    const x=entry[0],y=entry[1];
    if(x==="?"&&y==="?"){untracked++;continue;}
    if(x==="!"&&y==="!")continue;
    if(x!==" ")staged++;
    if(y!==" ")unstaged++;
    if(x==="R"||x==="C"||y==="R"||y==="C")i++;
  }
  const result={branch,staged,unstaged,untracked,ahead:Number(head.match(/\bahead (\d+)/)?.[1]??0),behind:Number(head.match(/\bbehind (\d+)/)?.[1]??0)};
  if(typeof diff==="string"){
    let added=0,removed=0;
    for(const line of diff.split("\n")){const m=line.match(/^(\d+)\t(\d+)\t/);if(m){added+=Number(m[1]);removed+=Number(m[2]);}}
    Object.assign(result,{added,removed});
  }
  return result;
}

function render(state={},git={},now=Math.floor(Date.now()/1000)) {
  const t=state.thread??{},m=t.model??{},u=t.usage??{},c=u.context??{},total=u.total??{},groups=[];
  const identity=[segment(clean(m.display_name)||"Codex","status-model")];
  if(clean(m.reasoning_level))identity.push(segment(clean(m.reasoning_level),"magenta"));
  if(clean(m.service_tier_display_name))identity.push(segment(clean(m.service_tier_display_name),"status-mode"));
  const cwd=clean(t.workspace?.cwd,1024),project=clean(cwd.split(/[\\/]/).filter(Boolean).pop());
  if(project)identity.push(segment(project,"status-path"));
  if(clean(git.branch))identity.push(segment(`⎇ ${clean(git.branch)}${git.staged||git.unstaged||git.untracked?"*":""}`,"status-branch"));
  if(clean(t.permissions?.display_name))identity.push(segment(clean(t.permissions.display_name),"status-mode"));
  if(clean(t.agent?.state))identity.push(segment(clean(t.agent.state),"status-state"));
  groups.push(row(identity));
  const used=c.used_tokens,size=c.context_window_size;
  const p=number(c.used_percentage)?c.used_percentage:number(used)&&number(size)&&size>0?100*used/size:null;
  if(number(p)){
    let label=`Ctx ${bar(p)} ${Math.round(p)}% used`;
    if(number(used)&&number(size)&&size>0)label+=` · ${short(used)}/${short(size)} · ${short(Math.max(0,size-used))} left`;
    groups.push(row([segment(label,color(p))]));
  }else if(number(used)){groups.push(row([segment(`Ctx ${short(used)} tokens`,"status-usage")]));}
  const limits=Array.isArray(state.account?.rate_limits)?state.account.rate_limits:[];
  const primary=limits.find(l=>l?.limit_id==="codex")??(limits.length===1?limits[0]:null);
  if(primary){
    const windows=[primary.primary_limit,primary.secondary_limit].filter(Boolean);
    for(const [minutes,label] of [[300,"5h"],[10080,"7d"]]){
      const w=windows.find(x=>x.window_minutes===minutes);
      if(!w||!number(w.used_percent))continue;
      const reset=resetAt(w.resets_at,now);
      groups.push(row([segment(`${label} ${Math.round(w.used_percent)}% used${reset?" ↻ "+reset:""}`,color(w.used_percent,70))]));
    }
  }
  const changes=[];
  if(git.staged)changes.push(`●${git.staged}`);
  if(git.unstaged)changes.push(`✚${git.unstaged}`);
  if(git.untracked)changes.push(`…${git.untracked}`);
  if(git.ahead)changes.push(`↑${git.ahead}`);
  if(git.behind)changes.push(`↓${git.behind}`);
  const gitRow=[];
  if(changes.length)gitRow.push(segment(`Git ${changes.join(" ")}`,"status-branch"));
  if(git.added)gitRow.push(segment(`+${git.added}`,"green"));
  if(git.removed)gitRow.push(segment(`−${git.removed}`,"red"));
  if(gitRow.length)groups.push(row(gitRow));
  const telemetry=[];
  if(number(total.total_input_tokens))telemetry.push(segment(`In ${short(total.total_input_tokens)}`,"status-usage"));
  if(number(total.output_tokens))telemetry.push(segment(`Out ${short(total.output_tokens)}`,"status-usage"));
  if(number(total.cache_read_input_tokens)&&number(total.total_input_tokens)&&total.total_input_tokens>0&&total.cache_read_input_tokens<=total.total_input_tokens){
    const hit=Math.round(100*total.cache_read_input_tokens/total.total_input_tokens);
    telemetry.push(segment(`Cache ${hit}%`,hit<50?"red":hit<80?"yellow":"status-metadata"));
  }
  if(number(u.cost?.total_cost_usd))telemetry.push(segment(`$${u.cost.total_cost_usd.toFixed(2)}`,"status-usage"));
  if(telemetry.length)groups.push(row(telemetry));
  return row(groups.flatMap((g,i)=>i?[segment("│","status-metadata"),g]:[g]),"wrap");
}

function respond(method,params={},gitFor=()=>({})){
  switch(method){
    case "initialize":return {protocolVersion:"2025-06-18",capabilities:{tools:{},resources:{}},serverInfo:{name:"app-configs-statusline",version:"1.0.0"}};
    case "ping":return {};
    case "tools/list":return {tools:[TOOL]};
    case "tools/call":if(params.name!==TOOL.name)throw new Error("Unknown tool");return {content:[{type:"text",text:`Status line resource: ${URI}`}]};
    case "resources/list":return {resources:[{name:"footer",uri:URI,mimeType:"application/json"}]};
    case "resources/templates/list":return {resourceTemplates:[]};
    case "resources/read":{
      if(params.uri!==URI)throw new Error("Unknown resource URI");
      const state=params._meta?.["com.openai/codex-statusline-state"]??{};
      return {contents:[{uri:URI,mimeType:"application/json",text:JSON.stringify(render(state,gitFor(state.thread?.workspace?.cwd)))}]};
    }
    default:throw new Error("Method not found");
  }
}

function runTests(){
 const assert=(ok,msg)=>{if(!ok)throw new Error(msg);};
 const flatten=x=>typeof x==="string"?x:x.children.map(flatten).join(" ");
 const g=parseGit("## feature...origin/feature [ahead 2, behind 1]\0M  a\0 M b\0?? c\0R  d\0old\0","12\t3\ta\n-\t-\tb\n");
 assert(g.staged===2&&g.unstaged===1&&g.untracked===1&&g.ahead===2&&g.behind===1&&g.added===12&&g.removed===3,"git counts");
 assert(Object.keys(parseGit(null,null)).length===0,"non-repo");
 assert(!("added" in parseGit("## main\0",null)),"unavailable diff");
 const state={thread:{model:{display_name:"Model",reasoning_level:"high"},workspace:{cwd:"/work/app-configs"},permissions:{display_name:"Workspace"},agent:{state:"working"},usage:{context:{used_tokens:90000,context_window_size:100000},total:{total_input_tokens:100000,output_tokens:5000,cache_read_input_tokens:90000},cost:{total_cost_usd:1.23}}},account:{rate_limits:[{limit_id:"codex",primary_limit:{window_minutes:300,used_percent:85,resets_at:4600},secondary_limit:{window_minutes:10080,used_percent:20}}]}};
 const s=flatten(render(state,g,1000));
 for(const expected of ["Model","high","app-configs","feature*","Workspace","working","90% used","10k left","5h 85% used ↻ 1h0m","7d 20% used","Cache 90%","$1.23","+12","−3"])assert(s.includes(expected),expected);
 assert(flatten(render({})).trim()==="Codex","missing fields");
 assert(color(74)==="green"&&color(75)==="yellow"&&color(85)==="#FF9F43"&&color(95)==="red"&&color(70,70)==="yellow","thresholds");
 assert(!flatten(render({account:{rate_limits:[{limit_id:"other",primary_limit:{window_minutes:300,used_percent:50}},{limit_id:"another"}]}})).includes("5h"),"ambiguous limit");
 assert(clean("a\u001bb")==="ab","control characters");
 assert(respond("tools/list").tools[0]._meta["openai/ui"].entrypoints[0].resourceUri===URI,"discovery");
 const read=respond("resources/read",{uri:URI,_meta:{"com.openai/codex-statusline-state":state}},()=>g);
 assert(flatten(JSON.parse(read.contents[0].text)).includes("app-configs"),"resource read");
 assert(respond("initialize").protocolVersion==="2025-06-18","initialize");
 return 10;
}

const gitCache = new Map();
function gitFor(cwd) {
  if (typeof cwd !== "string" || !isAbsolute(cwd)) return {};
  const now = Date.now();
  const cached = gitCache.get(cwd);
  if (cached && now - cached.at < 5000) return cached.value;
  const git = (...args) => {
    try {
      const result = spawnSync("git", ["-C", cwd, ...args], {
        encoding: "utf8", timeout: 200, maxBuffer: 131072,
        env: {...process.env, GIT_OPTIONAL_LOCKS:"0", GIT_TERMINAL_PROMPT:"0"}
      });
      return result.status === 0 ? result.stdout : null;
    } catch { return null; }
  };
  const status = git("status", "--porcelain=v1", "-z", "--branch", "--untracked-files=normal");
  const diff = status === null ? null : git("diff", "--no-ext-diff", "--no-textconv", "--numstat", "HEAD", "--");
  const value = parseGit(status, diff);
  if (gitCache.size >= 64) gitCache.delete(gitCache.keys().next().value);
  gitCache.set(cwd, {at:now, value});
  return value;
}
if (process.argv.includes("--self-test")) {
  console.log("Self-test passed (" + runTests() + " groups)");
} else {
  const lines = createInterface({input: process.stdin, crlfDelay: Infinity});
  for await (const line of lines) {
    let request;
    try { request = JSON.parse(line); }
    catch { console.log(JSON.stringify({jsonrpc:"2.0",id:null,error:{code:-32700,message:"Parse error"}})); continue; }
    if (!request || typeof request.method !== "string") {
      console.log(JSON.stringify({jsonrpc:"2.0",id:request?.id??null,error:{code:-32600,message:"Invalid request"}})); continue;
    }
    if (!Object.hasOwn(request,"id")) continue;
    const reply = {jsonrpc:"2.0",id:request.id};
    try { reply.result = respond(request.method,request.params??{},gitFor); }
    catch (err) { reply.error = {code:err.message==="Method not found"?-32601:-32602,message:"Invalid method or parameters"}; }
    console.log(JSON.stringify(reply));
  }
}
