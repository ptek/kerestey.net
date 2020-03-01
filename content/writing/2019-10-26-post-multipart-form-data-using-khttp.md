---
title: Post multipart/form-data with khttp
author: Pavlo Kerestey
---

A challenge that I had recently was sending some data as `json` to an endpoint 
as `multipart/form-data`, providing the right encoding, in a Kotlin codebase.

It turns out, that it is not as straight-forward to do with the current version
of [khttp][1] as I thought it would be. The only way I have found out, is to
implement the [multipart rfc][2] separately. For this I have used a workaround,
that currently, if data is supplied to khttp request as `ByteArrayInputStream`,
khttp will pass it on unchanged. So here is what I came up with:

```
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.Writer

fun Writer.writeAndFlush(string: String) {
    this.write(string)
    this.flush()
}

data class FormPart(val content: String, val type: String)

data class MultipartForm(
    val headers: Map<String,String>,
    val data: ByteArrayInputStream
) {
  companion object {
    fun create(data: Map<String,FormPart>): MultipartForm {
      val boundary = “BoundaryAsSpecifiedByRFC”
      val headers = mapOf(
        "Content-Type" to "multipart/form-data; boundary=${boundary}"
        )
      val requestBodyBytes = ByteArrayOutputStream()
      val writer = requestBodyBytes.writer()
      for ((key, payload) in data) {
        writer.writeAndFlush("--${boundary}\r\n")
        writer.writeAndFlush(
            "Content-Disposition: form-data; name=\"${key}\"
            )
        writer.writeAndFlush("\r\n")
        writer.writeAndFlush("Content-Type: ${payload.type}")
        writer.writeAndFlush("\r\n\r\n")
        writer.writeAndFlush(payload.content)
        writer.writeAndFlush("\r\n")
        writer.writeAndFlush("--${boundary}--\r\n")
      }
      writer.close()
      return MultipartForm(
        headers,
        ByteArrayInputStream(requestBodyBytes.toByteArray())
        )
    }
  }
}
```

To use this, one would first serialise the object into json, construct the
multipart using MultipartForm and use the resulting data to send the request:

```
val payload = FormPart(data, "application/json")
val form = MultipartForm.create(
  mapOf("payload" to payload)
)

post(url, headers=form.headers, data=form.data)
```

I have borrowed some ideas about how to deal with the Byte Arrays from khttp
directly. It also turns out, that the python requests library does not provide
such functionality either out of the box. The only way, apparently, to do it
is to use the [requests-toolbelt][3] with MultipartEncoder

[1]: https://khttp.readthedocs.io/en/latest/ 
[2]: https://www.w3.org/Protocols/rfc1341/7_2_Multipart.html
[3]: https://pypi.org/project/requests-toolbelt/
