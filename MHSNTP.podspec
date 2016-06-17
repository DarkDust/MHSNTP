Pod::Spec.new do |s|

  s.name         = "MHSNTP"
  s.version      = "0.0.3"
  s.summary      = "SNTP client library"
  s.description  = <<-DESC
  Easy to use SNTP client library.
  DESC

  s.homepage     = "https://github.com/DarkDust/MHSNTP"
  s.license      = { :type => "BSD", :file => "LICENSE" }
  s.author             = { "Marc Haisenko" => "marc@darkdust.net" }

  s.ios.deployment_target = "7.0"
  s.osx.deployment_target = "10.7"
  s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/DarkDust/MHSNTP.git", :tag => "#{s.version}" }
  s.source_files  = "MHSNTP/*.{h,m}"
  s.requires_arc = true

  s.dependency "CocoaAsyncSocket", "~> 7"

end

