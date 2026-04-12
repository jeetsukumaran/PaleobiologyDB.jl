# ---------------------------------------------------------------------------
# PhyloPicDB — HTTP primitive
#
# Single effectful entry point for all PhyloPic API requests.
# ---------------------------------------------------------------------------

"""
Base URL for the PhyloPic REST API.
"""
const PHYLOPIC_BASE_URL = "https://api.phylopic.org"

"""
    phylopic_get(url; retries=3, readtimeout=30) -> HTTP.Response

Perform an HTTP GET against the PhyloPic API at `url`.

Retries up to `retries` times with exponential back-off on transient failures
(non-4xx errors).  4xx client errors (400, 404, 410) are never retried — they
are re-raised immediately.

# Arguments

- `url`: The full request URL, including any query parameters.
- `retries`: Maximum number of attempts before re-raising the last error.
  Default `3`.
- `readtimeout`: Socket read timeout in seconds.  Default `30`.

# Returns

An `HTTP.Response` on success.

# Throws

Re-raises the last `HTTP.Exceptions.StatusError` (or any other exception) after
all retry attempts are exhausted.

# Examples

```julia
resp = phylopic_get("https://api.phylopic.org/ping")
resp.status  # 204
```
"""
function phylopic_get(
    url::AbstractString;
    retries::Int    = 3,
    readtimeout::Int = 30,
)::HTTP.Response
    last_err = nothing
    for attempt in 1:retries
        try
            return HTTP.get(url; readtimeout = readtimeout)
        catch err
            last_err = err
            # Client errors are definitive — retrying won't help.
            if err isa HTTP.Exceptions.StatusError && err.status in (400, 404, 410)
                rethrow(err)
            end
            attempt == retries && rethrow(err)
            sleep(0.5 * attempt)
        end
    end
    throw(last_err)
end
