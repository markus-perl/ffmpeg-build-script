const { resolve, basename } = require('path');
const { mkdirSync, readlinkSync, readdirSync } = require('fs');
const { execSync } = require('child_process');

function logAndExec(cmd) {
  console.log(`EXEC ${cmd}`);
  execSync(cmd);
}

const baseIncludesDir = resolve(__dirname, 'workspace/include');
const baseBinDir = resolve(__dirname, 'workspace/bin');
const baseLibDir = resolve(__dirname, 'workspace/lib');
const destDir = resolve(__dirname, 'workspace/mac');

try {
  logAndExec(`rm -r ${destDir}`);
} catch (err) {
  //
}
logAndExec(`mkdir -p ${destDir}`);

const skippedLibs = new Set();
const copiedLibs = new Set();
const missingLibs = new Set();
const namesWithoutVersion = new Set();

function copyDylibs(binaryName, base = baseBinDir) {
  const origPath = resolve(base, binaryName);
  const binaryPath = resolve(destDir, binaryName);

  logAndExec(`cp -a ${origPath} ${binaryPath}`);

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
          // copy sym-linked libraries as well
          let nameWithoutVersion = filename.split('.')[0];
          // libSDL2 weirdly has hypthen after then name (i.e., libSDL2-2.0.0.dylib)
          if (filename.includes('libSDL2')) {
            nameWithoutVersion = 'libSDL2';
          }
          namesWithoutVersion.add(nameWithoutVersion);
          const nameWithoutVersionLib = `${nameWithoutVersion}.dylib`;
          logAndExec(`cp -a ${resolve(baseLibDir, nameWithoutVersion)}*.dylib ${destDir}/.`);

          copyDylibs(filename, baseLibDir);
        }
      }
      libsToRewrite.push({path, filename});
    } else {
      skippedLibs.add(path);
    }
  }

  // find the non-sym-linked version of this library
  let actualBinaryPath = binaryPath;
  try {
    const actualBinaryName = readlinkSync(binaryPath);
    actualBinaryPath = resolve(destDir, actualBinaryName);
  } catch (err) {
    //
  }

  if (libsToRewrite.length > 0) {
    logAndExec(`install_name_tool -id @loader_path/${binaryName} ${libsToRewrite.map(({path, filename}) => `-change ${path} @loader_path/${filename}`).join(' ')} ${actualBinaryPath}`);
  }
}

copyDylibs('ffmpeg');
copyDylibs('ffprobe');

console.log('Copying includes');
logAndExec(`cp -r ${baseIncludesDir} ${destDir}/.`);

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
