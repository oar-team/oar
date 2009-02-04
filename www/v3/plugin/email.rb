class MailtoTag < Tags::DefaultTag

  infos( :name => 'Tag/Mailto',
         :author => 'Philip Hallstrom <philip-at-pjkh-dot-com>',
         :summary => "Prints out an obfuscated mailto link"
         )

  param 'email', nil, 'The email address to mailto tag.'
  param 'link', nil, 'The linkable portion to mailto tag.'
  param 'subject', nil, 'The subject of the mail message.'
  set_mandatory 'email', true

  register_tag 'mailto'

  def process_tag( tag, chain )
    email = param('email')
    link = param('link') || email
    subject = param('subject')
    tmp = "document.write(\"<a href='mailto:#{email}#{'?subject=' + subject unless subject.nil?}'>#{link}</a>\");"
    string = ''
    for i in 0...tmp.length
      string << sprintf("%%%x",tmp[i])
    end
    html = "<script type=\"text/javascript\">eval(unescape('#{string}'))</script>"
    html += "<noscript>#{link}</noscript>" unless link == email
    html
  end

end
