const { resolve, basename } = require('path');
const { mkdirSync } = require('fs');
const { execSync } = require('child_process');

function logAndExec(cmd) {
  console.log(`EXEC ${cmd}`);
  execSync(cmd);
}

const baseBinDir = resolve(__dirname, 'workspace/bin');
const baseLibDir = resolve(__dirname, 'workspace/lib');
const destDir = resolve(__dirname, 'workspace/mac');

logAndExec(`rm -r ${destDir}`);
logAndExec(`mkdir -p ${destDir}`);

const skippedLibs = new Set();
const copiedLibs = new Set();
const missingLibs = new Set();

function copyDylibs(binaryName, base = baseBinDir) {
  const origPath = resolve(base, binaryName);
  const binaryPath = resolve(destDir, binaryName);
  logAndExec(`cp ${origPath} ${binaryPath}`);

  console.log(`Inspecting ${binaryPath}`);
  const lines = execSync(`otool -L ${binaryPath}`).toString('utf8').split('\n');
  const libsToRewrite = [];
  for (const line of lines) {
    const match = /[^\s:]+/.exec(line);
    if (!match) {
      continue;
    }
    const [path] = match;
    if (path.startsWith('/usr/local')) {
      missingLibs.add(path);
    } else if (path.startsWith('/Users')) {
      const filename = basename(path);
      const newFilename = resolve(destDir, filename);
      if (!copiedLibs.has(path)) {
        copiedLibs.add(path);
        copiedLibs.add(newFilename);
        if (path !== newFilename) {
          logAndExec(`cp ${path} ${newFilename}`);
          logAndExec(`chmod u+w ${newFilename}`);
          copyDylibs(filename, baseLibDir);
        }
      }
      libsToRewrite.push({path, filename});
    } else {
      skippedLibs.add(path);
    }
  }
  if (libsToRewrite.length > 0) {
    logAndExec(`install_name_tool -id @loader_path/${binaryName} ${libsToRewrite.map(({path, filename}) => `-change ${path} @loader_path/${filename}`).join(' ')} ${binaryPath}`);
  }
}

copyDylibs('ffmpeg');
copyDylibs('ffprobe');

for (const lib of Array.from(skippedLibs).sort()) {
  console.log(`[NOTE] skipped ${lib}`);
}
for (const lib of Array.from(copiedLibs).sort()) {
  if (!lib.startsWith(destDir)) {
    console.log(`Copied ${lib}`);
  }
}
for (const lib of Array.from(missingLibs).sort()) {
  console.log(`[WARNING] missing ${lib}`);
}
