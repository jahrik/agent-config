-- 1. Tool-call frequency by tool name
SELECT
  json_extract_string(tool, '$.name') as tool_name,
  count(*) as frequency
FROM (
  SELECT unnest(from_json(message.content, '["JSON"]')) as tool
  FROM read_json_auto('~/.claude/projects/**/*.jsonl', ignore_errors=true)
  WHERE message.role = 'assistant'
)
WHERE json_extract_string(tool, '$.type') = 'tool_use'
GROUP BY 1 ORDER BY 2 DESC LIMIT 20;

-- 2. Bash command-word histogram
SELECT
  split_part(json_extract_string(tool, '$.input.command'), ' ', 1) as command_word,
  count(*) as frequency
FROM (
  SELECT unnest(from_json(message.content, '["JSON"]')) as tool
  FROM read_json_auto('~/.claude/projects/**/*.jsonl', ignore_errors=true)
  WHERE message.role = 'assistant'
)
WHERE json_extract_string(tool, '$.type') = 'tool_use'
  AND json_extract_string(tool, '$.name') = 'Bash'
GROUP BY 1 ORDER BY 2 DESC LIMIT 20;

-- 3. Tool-error rate
SELECT
  COALESCE(json_extract_string(tool, '$.is_error'), 'false') as is_error,
  count(*) as frequency
FROM (
  SELECT unnest(from_json(message.content, '["JSON"]')) as tool
  FROM read_json_auto('~/.claude/projects/**/*.jsonl', ignore_errors=true)
  WHERE message.role = 'user'
)
WHERE json_extract_string(tool, '$.type') = 'tool_result'
GROUP BY 1 ORDER BY 2 DESC;

-- 4. Token/cache usage by session
SELECT
  sessionId,
  sum(message.usage.input_tokens) as input_tokens,
  sum(message.usage.output_tokens) as output_tokens,
  sum(message.usage.cache_read_input_tokens) as cache_read,
  sum(message.usage.cache_creation_input_tokens) as cache_creation
FROM read_json_auto('~/.claude/projects/**/*.jsonl', ignore_errors=true)
WHERE message.usage IS NOT NULL
GROUP BY sessionId
ORDER BY (sum(message.usage.input_tokens) + sum(message.usage.output_tokens)) DESC
LIMIT 10;

-- 5. Largest-context sessions
SELECT
  sessionId,
  max(message.usage.input_tokens + message.usage.cache_read_input_tokens + message.usage.cache_creation_input_tokens) as max_context_tokens
FROM read_json_auto('~/.claude/projects/**/*.jsonl', ignore_errors=true)
WHERE message.usage IS NOT NULL
GROUP BY sessionId
ORDER BY max_context_tokens DESC
LIMIT 10;
