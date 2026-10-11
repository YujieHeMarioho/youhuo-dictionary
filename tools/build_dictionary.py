#!/usr/bin/env python3
"""Convert licensed ECDICT CSV to the read-only app SQLite database."""
import csv, sqlite3, gzip, shutil, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/ecdict.csv'; dest=root/'data/dictionary.sqlite'
if dest.exists(): dest.unlink()
con=sqlite3.connect(dest)
fields=['word','phonetic','translation','definition','pos','exchange','tag']
con.execute('CREATE TABLE entries ('+','.join(f+' TEXT NOT NULL' for f in fields)+')')
with source.open(encoding='utf-8',newline='') as handle:
 rows=csv.DictReader(handle)
 con.executemany('INSERT INTO entries VALUES (?,?,?,?,?,?,?)', ([r.get(f,'') or '' for f in fields] for r in rows if r.get('word')))
con.execute('CREATE INDEX word_index ON entries(word COLLATE NOCASE)')
con.commit()
print('Entries:',con.execute('SELECT COUNT(*) FROM entries').fetchone()[0])
con.execute('VACUUM'); con.close()
with dest.open('rb') as src, gzip.GzipFile(filename=str(dest)+'.gz',mode='wb',mtime=0) as dst: shutil.copyfileobj(src,dst)
print('CSV SHA256:',hashlib.sha256(source.read_bytes()).hexdigest())
print('Compressed bytes:',Path(str(dest)+'.gz').stat().st_size)
