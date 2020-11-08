---
title: Announcing unverified.email
author: Pavlo Kerestey
---

# Important Update.

June 27, 2020

The service over at api.unverified.email has been keeping up since the announcement.
I could not been happier with it. To support it better, though, I would need to 
spend more time on it, which I currently do not have.

Therefore I have decided to switch 
https://api.unverified.email off at the end of 
August 2020. If you want to keep using unverified.email for your project, you can
do so by running the service yourself on your infrastructure using the 
[code available at github](https://github.com/honest-technology/api.unverified.email).

----

Original article on April 5, 2020

I want to announce unverified.email - a hosted service to test emails. I have
been running it for several weeks now, and I am quite happy with the result so
far. With the service, one can use automated testing to verify that the email
logic in your application is correct.

unverified.email is a catch-all SMTP server. You can use it programmatically via
its API at https://api.unverified.email, and
the article shows an example of its usage. To follow, you would need `curl` [[1]]
and `jq` [[2]] installed (on Linux, use the package manager, and macOS supplies
it via homebrew).

## Setup of the test

First, in our automated test code, we should prepare the environment to point at
the test SMTP server: smtp.unverified.email on port 25. That way, the test
automation is ready to send emails to be captured and verified when ready.

Next, we can create a mailbox via `HTTP GET` request to
https://api.unverified.email/create and
remember the `mailbox_id`. The mailbox exists for 5 minutes and is deleted
after, purging all the emails within:

```bash
curl -s https://api.unverified.email/create | jq
```

The result should look something like this:

```json
{
  "mailbox": "7bb1d8d0-7b00-4375-a3fd-d119b56042f2@unverified.email",
  "created": "2020-03-20T10:29:02.244Z",
  "receive": "https://api.unverified.email/receive/7bb1d8d0-7b00-4375-a3fd-d119b56042f2",
  "mailbox_id": "7bb1d8d0-7b00-4375-a3fd-d119b56042f2"
}
```

## Sending the mail

The `mailbox_id` from the above setup should be included somewhere in the text
of the email, the subject, the bcc address, the headers, or any other field
(even email address of the sender or recipient will do).

We can now send the email to the intended recipients, so it is captured by the
smtp.unverified.email server for later retrieval by the test. The server does
not forward it anywhere further, no matter which addresses you put in the
recipient's field.

For demonstration, we create a file `mail.txt` with the X-Unverified-Mailbox
header that contains our `mailbox_id`:

```bash
cat << EOF > mail.txt
To: customer@example.com
From: developer@example.com
Subject: This is a text message
Content-Type: text/plain; charset="utf8"
X-Unverified-Mailbox: 7bb1d8d0-7b00-4375-a3fd-d119b56042f2

A test email message created by the application
EOF
```

And then send it away (using curl):

```bash
curl -s --url 'smtp://smtp.unverified.email:25' \
  --mail-from 'developer@example.com' \
  --mail-rcpt 'customer@example.com' \
  --upload-file mail.txt
```

## Fetching the email via API to verify the result

Now the test can retrieve the mail back via `HTTP GET` request to
`https://api.unverified.email/receive/<mailbox_id>` (if you follow this, please
use the `mailbox_id` that you have received in the setup step):

```bash
curl -s https://api.unverified.email/receive/7bb1d8d0-7b00-4375-a3fd-d119b56042f2 | jq
```

The result here should look something like this (I have cut off the
`"full_content"` field to make it more readable):

```json
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
using your `mailbox_id` from the setup step, of course).

```bash
curl -s https://api.unverified.email/receive/7bb1d8d0-7b00-4375-a3fd-d119b56042f2 | jq -r '.[] | .full_content'
```

The result should be something like this:ss

```
Return-Path: developer@example.com
Delivered-To: customer@example.com
Received: from mail.txt (h-62.96.253.90.host.de.colt.net [62.96.253.90])
    by api-01 (OpenSMTPD) with ESMTP id 10f97d91
    for <customer@example.com>;
    Thu, 20 Mar 2020 10:30:59 +0000 (UTC)
To: customer@example.com
Subject: This is a text message
From: developer@example.com
Content-Type: text/plain; charset="utf8"
X-Unverified-Mailbox: 7bb1d8d0-7b00-4375-a3fd-d119b56042f2

A test email message created by the application
```

You can create as many mailboxes as you want, and they are deleted 5
minutes after creation.

The `/receive/<mailbox_id>` endpoint is waiting for emails to show up on the
server for around 15 seconds, so you do not need to refresh the url repeatedly.

The code is available at
[https://github.com/honest-technology/api.unverified.email](https://github.com/honest-technology/api.unverified.email)
where you can also open issues if something needs attention. You can also run
the service on your infrastructure if needed. Drop me a note if you do -
I would be very interested to know if it is useful to anyone.

#### Some alternatives:

- [**mailtrap**](https://rubygems.org/gems/mailtrap), a ruby library
- [**mailhog**](https://github.com/mailhog/MailHog), a standalone smtp service
  written in golang

[1]: https://curl.haxx.se/download.html
[2]: https://stedolan.github.io/jq/download/
