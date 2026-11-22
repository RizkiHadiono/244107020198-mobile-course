// Mengambil data run GitHub Actions sebagai bukti mentah, tanpa perlu gh CLI.
//
// Pemakaian:
//   node tool/ci/fetch_run.mjs <run-id>
//   node tool/ci/fetch_run.mjs            (memakai run terakhir pada main)
//
// Hasil:
//   tool/ci/results/run-<id>.json          detail run dan tiap job/step
//   tool/ci/results/artifacts-<id>.json    daftar artefak beserta ukurannya
//
// Repositori ini publik, sehingga REST API GitHub dapat dibaca tanpa token.
// Jika suatu saat repositori menjadi privat, set GITHUB_TOKEN di environment.
import fs from 'node:fs';
import path from 'node:path';

const OWNER = process.env.GITHUB_OWNER ?? 'RizkiHadiono';
const REPO = process.env.GITHUB_REPO ?? '244107020198-mobile-course';
const BRANCH = process.env.GITHUB_BRANCH ?? 'main';
const OUT = path.resolve('tool/ci/results');

const headers = {
  Accept: 'application/vnd.github+json',
  'User-Agent': 'week13-ci-evidence',
  'X-GitHub-Api-Version': '2022-11-28',
};
if (process.env.GITHUB_TOKEN) {
  headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
}

async function api(pathname) {
  const url = `https://api.github.com/repos/${OWNER}/${REPO}${pathname}`;
  const res = await fetch(url, { headers });
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText} untuk ${url}`);
  }
  return res.json();
}

/// Run terakhir pada branch utama, atau run yang ditentukan argumen.
async function resolveRunId() {
  const arg = process.argv[2];
  if (arg) return Number(arg);

  const runs = await api(
    `/actions/runs?branch=${BRANCH}&per_page=1&exclude_pull_requests=true`,
  );
  if (!runs.workflow_runs?.length) {
    throw new Error(`Belum ada run pada branch ${BRANCH}.`);
  }
  return runs.workflow_runs[0].id;
}

/// Ringkas data run agar mudah dibaca di laporan.
function summarize(run, jobs, artifacts) {
  return {
    id: run.id,
    name: run.name,
    title: run.display_title,
    event: run.event,
    branch: run.head_branch,
    commit: run.head_sha,
    commitShort: run.head_sha?.slice(0, 7),
    status: run.status,
    conclusion: run.conclusion,
    runNumber: run.run_number,
    attempt: run.run_attempt,
    createdAt: run.created_at,
    updatedAt: run.updated_at,
    durationSeconds:
      run.created_at && run.updated_at
        ? Math.round(
            (new Date(run.updated_at) - new Date(run.created_at)) / 1000,
          )
        : null,
    htmlUrl: run.html_url,
    jobs: (jobs.jobs ?? []).map((job) => ({
      name: job.name,
      status: job.status,
      conclusion: job.conclusion,
      startedAt: job.started_at,
      completedAt: job.completed_at,
      steps: (job.steps ?? []).map((step) => ({
        number: step.number,
        name: step.name,
        status: step.status,
        conclusion: step.conclusion,
        startedAt: step.started_at,
        completedAt: step.completed_at,
        durationSeconds:
          step.started_at && step.completed_at
            ? Math.round(
                (new Date(step.completed_at) - new Date(step.started_at)) / 1000,
              )
            : null,
      })),
    })),
    artifacts: (artifacts.artifacts ?? []).map((a) => ({
      name: a.name,
      sizeBytes: a.size_in_bytes,
      sizeMB: Number((a.size_in_bytes / 1024 / 1024).toFixed(2)),
      expired: a.expired,
      createdAt: a.created_at,
      downloadUrl: a.archive_download_url,
    })),
  };
}

fs.mkdirSync(OUT, { recursive: true });

try {
  const runId = await resolveRunId();
  console.log(`Mengambil run ${runId} dari ${OWNER}/${REPO}...`);

  const [run, jobs, artifacts] = await Promise.all([
    api(`/actions/runs/${runId}`),
    api(`/actions/runs/${runId}/jobs`),
    api(`/actions/runs/${runId}/artifacts`),
  ]);

  const data = summarize(run, jobs, artifacts);

  fs.writeFileSync(
    path.join(OUT, `run-${runId}.json`),
    `${JSON.stringify(data, null, 2)}\n`,
    'utf8',
  );
  fs.writeFileSync(
    path.join(OUT, `artifacts-${runId}.json`),
    `${JSON.stringify(data.artifacts, null, 2)}\n`,
    'utf8',
  );

  console.log(`\nRun #${data.runNumber} (${data.event}) commit ${data.commitShort}`);
  console.log(`Status    : ${data.status} / ${data.conclusion}`);
  console.log(`Durasi    : ${data.durationSeconds} detik`);
  console.log(`Halaman   : ${data.htmlUrl}`);
  console.log('\nStep:');
  for (const job of data.jobs) {
    console.log(`  ${job.name}: ${job.conclusion}`);
    for (const step of job.steps) {
      const mark = step.conclusion === 'success' ? 'OK  ' : 'X   ';
      const secs =
        step.durationSeconds === null ? '' : ` (${step.durationSeconds} detik)`;
      console.log(
        `    ${mark}${step.number}. ${step.name}${secs}`,
      );
    }
  }
  console.log('\nArtefak:');
  for (const a of data.artifacts) {
    console.log(`  ${a.name} (${a.sizeMB} MB, kedaluwarsa=${a.expired})`);
  }
  console.log(`\nTersimpan di ${path.relative(process.cwd(), OUT)}`);
} catch (error) {
  console.error(`Gagal mengambil data run: ${error.message}`);
  process.exit(1);
}
