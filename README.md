# Darth

Environment variables:

- email sending

```
MAILGUN_API_KEY
MAILGUN_DOMAIN
```

- google api

```
GOTH_CREDENTENTIALS
```

These credentials need to be valid.
That's why I cannot provide mock data here.
It is easiest in development mode to use the secrets
from the former `darth_api` repo.
This would look something like this:
`GOTH_CREDENTIALS=$(cat ~/rep/darth-api/config/google_api_dev.json) make run`.
