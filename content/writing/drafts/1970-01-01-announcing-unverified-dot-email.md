---
title: Announcing unverified.email
author: Pavlo Kerestey
---

I would like to announce unverified.email - a hosted service to test emails. I
have been running it for several weeks now, and I am quite happy with the result
so far. Testing emails this way, one can verify that the whole setup has been
taken care of automatically end-to-end.

unverified.email is a catch-all SMTP server. You can use it programmatically via
its API at [https://api.unverified.email](https://api.unverified.email) and here
is an example that show its usage. To follow, you would need `curl` [[1]]
and `jq` [[2]] installed (your system installation should be fine).

## Setup

In the test setup, one would create a test mailbox via `HTTP GET` request to
[https://api.unverified.email/create](https://api.unverified.email/create) and
remember the `mailbox_id`. The mailbox will exist for 5 minutes and will be
deleted after, purging all the emails.

```
curl -s https://api.unverified.email/create | jq
```

Result should look something like this:

```
{
  "mailbox": "7bb1d8d0-7b00-4375-a3fd-d119b56042f2@unverified.email",
  "created": "2019-11-20T10:29:02.244Z",
  "receive": "https://api.unverified.email/receive/7bb1d8d0-7b00-4375-a3fd-d119b56042f2",
  "mailbox_id": "7bb1d8d0-7b00-4375-a3fd-d119b56042f2"
}
```

Now if we set the SMTP server of the application that is being tested to
smtp.unverified.email on port 25, we would be ready to send a mail to be
captured. Note that examples below are already take care of this.

## Sending the mail

The `mailbox_id` from the above setup should be included somewhere in the text
of the email, the subject, the bcc address, the headers, or any other field
(even email address of the sender or recipient will do).

The email can now be sent by the tested application to intended recipients and
captured by the smtp.unverified.email server for later retrieval by the test.
The server will not forward it anywhere further no matter which address you put
in the recipients field.

Here, we create a file `mail.txt` with the X-Unverified-Mailbox header that
contains our `mailbox_id`:

```
cat << EOF > mail.txt
To: customer@example.com
From: developer@example.com
Subject: This is a text message
Content-Type: text/plain; charset="utf8"
X-Unverified-Mailbox: 7bb1d8d0-7b00-4375-a3fd-d119b56042f2

This is the email message created by the application
EOF
```

And send it (using curl):

```
curl -s --url 'smtp://smtp.unverified.email:25' \
  --mail-from 'developer@example.com' \
  --mail-rcpt 'customer@example.com' \
  --upload-file mail.txt
```

## Fetching the email via API to verify the result

Now the test can retrieve the mail back via `HTTP GET` request to
`https://api.unverified.email/receive/<mailbox_id>` (if you follow this, don't
forget to use your `mailbox_id` from the setup):

```
curl -s https://api.unverified.email/receive/7bb1d8d0-7b00-4375-a3fd-d119b56042f2 | jq
```

The result here should look something like this: I have cut off the
`"full_content"` field so it is more readable

```
[
  {
    "address_to": "customer@example.com",
    "address_from": "developer@example.com",
    "subject": "This is a text message",
    "full_content": "Return-Path: developer@example.com\nDe<...>"
  }
]
```

Using `jq -r '.[] | .full_content'` one can also see the full content (again
using your `mailbox_id` from the setup, of course).

```
curl -s https://api.unverified.email/receive/7bb1d8d0-7b00-4375-a3fd-d119b56042f2 | jq -r '.[] | .full_content'
```

The result should be something like this:

```
Return-Path: developer@example.com
Delivered-To: customer@example.com
Received: from mail.txt (h-62.96.253.90.host.de.colt.net [62.96.253.90])
    by api-01 (OpenSMTPD) with ESMTP id 10f97d91
    for <customer@example.com>;
    Thu, 20 Nov 2019 10:30:59 +0000 (UTC)
To: customer@example.com
Subject: This is a text message
From: developer@example.com
Content-Type: text/plain; charset="utf8"
X-Unverified-Mailbox: 7bb1d8d0-7b00-4375-a3fd-d119b56042f2

This will be any valid txt message created by the application
```

You can create as many mailboxes as you want and they will be deleted 5
minutes after they are created.

The `/receive/<mailbox_id>` endpoint will wait for emails to show up on the
server for around 15 seconds, so you don't need to refresh the url repeatedly.

The code is available at
[https://github.com/ptek/api.unverified.email](https://github.com/ptek/api.unverified.email)
where you can also open issues if something needs attention. You can also run
the service on your own infrastructure, if needed. Drop me a note if you do -
I would be very interested to know if it is useful to someone.

#### Some alternatives:

- [**mailtrap**](https://rubygems.org/gems/mailtrap), a ruby library
- [**mailhog**](https://github.com/mailhog/MailHog), a standalone smtp service
  written in golang

[1]: https://curl.haxx.se/download.html
[2]: https://stedolan.github.io/jq/download/
