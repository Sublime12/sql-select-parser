# Building a simple parser for a sql query

```sql

for this query:
select c1, c2
from  table
where condition

the lexer return this
.TokenSelect
.TokenId |c1|,
.TokenComma
.TokenId |c2|,
.TokenFrom
.TokenId |table|,
.TokenWhere
.TokenId |condition|,
.TokenEnd
```
