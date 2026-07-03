#!/usr/bin/env node

const { spawn, execSync } = require('child_process');

function checkPython() {
  try {
    execSync('python3 --version', { stdio: 'ignore' });
    return 'python3';
  } catch (e) {
    try {
      execSync('python --version', { stdio: 'ignore' });
      return 'python';
    } catch (e2) {
      return null;
    }
  }
}

function checkStreeIO(pythonCmd) {
  try {
    execSync(`${pythonCmd} -c "import streeio"`, { stdio: 'ignore' });
    return true;
  } catch (e) {
    return false;
  }
}

const pythonCmd = checkPython();
if (!pythonCmd) {
  console.error('\x1b[31m[ERREUR] Python n\'est pas détecté sur votre système.\x1b[0m');
  console.error('Veuillez installer Python (https://www.python.org/downloads/) pour exécuter streeio.');
  process.exit(1);
}

if (!checkStreeIO(pythonCmd)) {
  console.log('\x1b[36m🚀 Installation de StreeIO (Python CLI)...\x1b[0m');
  try {
    execSync(`${pythonCmd} -m pip install git+https://github.com/AdamZoda/stremio.git`, { stdio: 'inherit' });
    console.log('\x1b[32m✔ StreeIO installé avec succès !\x1b[0m\n');
  } catch (err) {
    console.error('\x1b[31m[ERREUR] Impossible d\'installer le package Python StreeIO via pip.\x1b[0m');
    process.exit(1);
  }
}

// Lancer le script python
const args = process.argv.slice(2);
const pythonProcess = spawn(pythonCmd, ['-m', 'streeio', ...args], { stdio: 'inherit' });

pythonProcess.on('close', (code) => {
  process.exit(code);
});
