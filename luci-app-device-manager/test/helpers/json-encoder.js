'use strict';
const fs = require('node:fs');
const fields = fs.readFileSync(process.argv[2], 'utf8').split('\0');
const root = {}, stack = [root];
for (let i = 0; i + 2 < fields.length; i += 3) {
    const [type, key, raw] = fields.slice(i, i + 3);
    if (type === 'init') continue;
    if (type === 'close') { stack.pop(); continue; }
    const value = type === 'array' ? [] : type === 'object' ? {} : type === 'boolean' ? raw === '1' : raw;
    const current = stack[stack.length - 1];
    if (Array.isArray(current)) current.push(value);
    else current[key] = value;
    if (type === 'array' || type === 'object') stack.push(value);
}
process.stdout.write(JSON.stringify(root) + '\n');
