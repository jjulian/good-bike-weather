#!/usr/bin/env ruby
# Send a test email using Resend.

require "resend"

Resend.api_key = ENV.fetch("RESEND_API_KEY")

html = <<~HTML
  <div style="font-family:sans-serif;max-width:400px;margin:0 auto;padding:20px;background:linear-gradient(135deg,#667eea,#764ba2);border-radius:12px">
    <h1 style="color:#fff;font-size:32px;margin:0 0 10px;text-shadow:2px 2px 4px rgba(0,0,0,0.2)">Hello World!</h1>
    <p style="color:#e8e8ff;font-size:18px;margin:0">Greetings from your scheduled workflow</p>
  </div>
HTML

params = {
  from: ENV.fetch("EMAIL_FROM"),
  to: ENV.fetch("EMAIL_TO"),
  subject: "Hello World",
  html: html
}

response = Resend::Emails.send(params)
puts response
