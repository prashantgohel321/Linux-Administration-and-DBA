<center><h1> PGSQL Templates: template0 and template1</h1></center>

<br>
<br>

## In simple words:
- PGSQL creates a new database by copying an existing database called template.
- By default, PGSQL uses template1.
- template0 is a special clean template kept only for safe and customized database creation.

<br>
<br>

---

## What is template1?
- template1 is the default template database.
- If I run CREATE DATABASE mydb; without mentioning any template, PGSQL automatically copies template1.
- This means whatever exists inside template1 becomes a part for the new database.

<br>

- Fresh PGSQL installation keeps template1 very basic, but it is modifiable (only objects like schema, extensions...).
- I can add comonly required extensions, schemas, or default objects into template1.
- After that, every new database will automatically include those things.

<br>

- Because of this, template1 is used to maintain consistency across databases in an organization.

<br>

- However, the locale and encoding of template1 are fixed at creation time.
- They cannot be changed later because database internals, indexes and text rules are already built using them.

---

<br>
<br>

## When do i use template1?

- I use template1 when:
  - I want a standard database structure
  - All databases should follow the same rules.
  - I want default extensions or schemas to exist automatically
- This is the template used in daily database creation.

---

<br>
<br>

## What is template0?

- template0 is PGSQL's original, untouched factory copy of a database.

<br>

- It is kept in a clean state and is not meant to be modified.
- PGSQL intentionally protects it so that one safe reference database always exists.

<br>

- template0 solves this by acting as a permanent clean starting point.

---

<br>
<br>

## When do i use template0?
- I use template0 when:
  - I need a different <abbr title="Locale is simply a set of language rules that PGSQL follows when it works with text. It decides how strings are compared and sorted, how characters are treated, and which text comes first or later. Because of this, locale direcly affects ORDER BY, text indexes, and string comparisons inside the database.">locale</abbr>.
  - I need a different <abbr title="Encoding defines which characters a database can store and understand. UTF-8 supports al languages and symbols, which is why it is the safest and most widely used encoding in real production systems.">encoding (UTF-8)</abbr>.
  - I want a completely clean database without custom objects.
Example:
```sql
CREATE DATABASE mydb
TEMPLATE template0
ENCODING 'UTF8'
LC_COLLATE 'en_US.UTF-8'
LC_CTYPE 'en_US.UTF-8';
```

> This is not possible with template0 if the locale or encoding does not match.

---

<br>
<br>

## Key differences
- template1:
  - Default template
  - Modifiable
  - Used for standard database creation
  - Locale and encoding are fixed
- template0
  - Clean and read-only
  - Not modifiable
  - Used for custom locale / encoding
  - Acts as a safety backup template

---

<br>
<br>