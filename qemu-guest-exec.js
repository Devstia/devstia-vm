// const { log, setLoggingEnabled } = require('./logger'); // Import the logger
const net = require('net');
const SOCKET_PATH = '/tmp/qga.sock'; // Path to the QEMU Guest Agent socket

// Dummy log function
function log(message, level = 'info') {
  const levels = { info: 'INFO', error: 'ERROR', warn: 'WARN' };
  console.log(`[${levels[level] || 'INFO'}]: ${message}`);
}

// Dummy setLoggingEnabled function
function setLoggingEnabled(enabled) {
  console.log(`Logging is now ${enabled ? 'enabled' : 'disabled'}`);
}

function executeCommandInGuest(command, callback) {
  const tempOutput = `/tmp/output-${Math.random().toString(36).substring(2, 15)}.txt`;

  const client = net.createConnection(SOCKET_PATH, () => {
    log('Connected to QEMU Guest Agent');

    const executeCommand = {
      execute: 'guest-exec',
      arguments: {
        path: '/bin/bash',
        arg: ['-c', `${command} > ${tempOutput} 2>&1`]
      }
    };

    log(`Executing command: ${JSON.stringify(executeCommand)}`);
    client.write(JSON.stringify(executeCommand));
  });

  let fileHandle = null;
  let callbackInvoked = false;

  client.on('data', (data) => {
    if (callbackInvoked) return;

    const response = JSON.parse(data.toString());
    log(`Received response: ${JSON.stringify(response)}`);

    if (response.return && response.return.pid) {
      const pid = response.return.pid;
      const statusCommand = {
        execute: 'guest-exec-status',
        arguments: { pid }
      };

      log('Monitoring command execution...');
      setTimeout(() => {
        client.write(JSON.stringify(statusCommand));
      }, 2000);
    } else if (response.return && response.return.exited) {
      const openFileCommand = {
        execute: 'guest-file-open',
        arguments: {
          path: tempOutput,
          mode: 'r'
        }
      };

      log(`Opening output file: ${JSON.stringify(openFileCommand)}`);
      client.write(JSON.stringify(openFileCommand));
    } else if (response.return && typeof response.return === 'number') {
      fileHandle = response.return;
      log(`File opened successfully. Handle: ${fileHandle}`);

      const readFileCommand = {
        execute: 'guest-file-read',
        arguments: {
          handle: fileHandle,
          count: 4096
        }
      };

      log(`Reading output file: ${JSON.stringify(readFileCommand)}`);
      client.write(JSON.stringify(readFileCommand));
    } else if (response.return && response.return['buf-b64']) {
      const fileContent = Buffer.from(response.return['buf-b64'], 'base64').toString();
      log(`Command output: ${fileContent}`);

      if (response.return.eof) {
        const closeFileCommand = {
          execute: 'guest-file-close',
          arguments: {
            handle: fileHandle
          }
        };

        log(`Closing file handle: ${JSON.stringify(closeFileCommand)}`);
        client.write(JSON.stringify(closeFileCommand));

        const cleanupCommand = {
          execute: 'guest-exec',
          arguments: {
            path: '/bin/bash',
            arg: ['-c', `rm -f ${tempOutput}`]
          }
        };

        log(`Cleaning up temporary file: ${JSON.stringify(cleanupCommand)}`);
        client.write(JSON.stringify(cleanupCommand));

        callbackInvoked = true;
        callback(null, fileContent);
        client.end();
      }
    } else if (response.error) {
      log(`Error: ${response.error.desc}`, 'error');
      client.end();
      callbackInvoked = true;
      callback(new Error(response.error.desc));
    }
  });

  client.on('end', () => {
    log('Disconnected from QEMU Guest Agent');
  });

  client.on('error', (err) => {
    log(`Error: ${err.message}`, 'error');
    if (!callbackInvoked) {
      callbackInvoked = true;
      callback(err);
    }
    client.end();
  });
}

// Example usage:
setLoggingEnabled(true); // Enable or disable logging

executeCommandInGuest('head -n 10 /tmp/hcpp.log', (err, output) => {
  if (err) {
    log(`Error executing command: ${err.message}`, 'error');
  } else {
    log(`Command output: ${output}`);
  }
});