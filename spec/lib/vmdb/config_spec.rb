describe VMDB::Config do
  let(:password) { "pa$$w0rd" }
  let(:enc_pass) { MiqPassword.encrypt(password) }

  it ".get_file" do
    stub_settings(:http_proxy => {:host => "proxy.example.com", :user => "user", :password => password, :port => 80})

    expect(VMDB::Config.get_file).to eq(
      "---\n:http_proxy:\n  :host: proxy.example.com\n  :user: user\n  :password: #{enc_pass}\n  :port: 80\n"
    )
  end

  context ".save_file" do
    it "normal" do
      EvmSpecHelper.local_miq_server
      stub_my_server_settings

      data = Settings.to_hash
      data.store_path(:api, :token_ttl, "1.day")
      data = data.to_yaml

      expect(VMDB::Config.save_file(data)).to be true

      expect(SettingsChange.count).to eq(1)
      expect(SettingsChange.first).to have_attributes(:key => '/api/token_ttl', :value => "1.day")
    end

    it "catches syntax errors" do
      errors = VMDB::Config.save_file("xxx")
      expect(errors.length).to eq(1)
      expect(errors.first[0]).to eq(:contents)
      expect(errors.first[1]).to start_with("File contents are malformed")
    end
  end

  it "#save" do
    EvmSpecHelper.local_miq_server
    stub_my_server_settings

    config = VMDB::Config.new("vmdb")
    config.config.store_path(:api, :token_ttl, "1.day")
    config.save

    expect(SettingsChange.count).to eq(1)
    expect(SettingsChange.first).to have_attributes(:key => '/api/token_ttl', :value => "1.day")
  end

  it "#set_worker_setting!" do
    EvmSpecHelper.local_miq_server
    stub_my_server_settings

    config = VMDB::Config.new("vmdb")
    config.set_worker_setting!(:MiqEmsMetricsCollectorWorker, :memory_threshold, "1.terabyte")

    fq_keys = [:workers, :worker_base, :queue_worker_base, :ems_metrics_collector_worker, :memory_threshold]
    v = config.config.fetch_path(fq_keys).to_i_with_method
    expect(v).to eq(1.terabyte)
  end

  # HACK: Temporary fix because zone name is stored in the configuration, but
  #   when calling EvmSpecHelper.local_miq_server, it does not update the
  #   corresponding settings.  enqueue_for_server expects that the zone is set,
  #   and this can get messed up during Config activation during a change.
  def stub_my_server_settings
    server = MiqServer.my_server
    allow(server).to receive(:enqueue_for_server)
  end
end
