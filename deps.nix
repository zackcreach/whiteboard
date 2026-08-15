{ lib, beamPackages, overrides ? (x: y: {}) }:

let
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildErlangMk = lib.makeOverridable beamPackages.buildErlangMk;

  self = packages // (overrides self packages);

  packages = with beamPackages; with self; {
    bandit = buildMix rec {
      name = "bandit";
      version = "1.12.4";

      src = fetchHex {
        pkg = "bandit";
        version = "${version}";
        sha256 = "84513318c5752a2a8017664450f889b47fae5d53d64698ddf1e4fb09a7449e8d";
      };

      beamDeps = [ hpax plug telemetry thousand_island websock ];
    };

    bcrypt_elixir = buildMix rec {
      name = "bcrypt_elixir";
      version = "3.3.2";

      src = fetchHex {
        pkg = "bcrypt_elixir";
        version = "${version}";
        sha256 = "471be5151874ae7931911057d1467d908955f93554f7a6cd1b7d804cac8cef53";
      };

      beamDeps = [ comeonin elixir_make ];
    };

    cc_precompiler = buildMix rec {
      name = "cc_precompiler";
      version = "0.1.11";

      src = fetchHex {
        pkg = "cc_precompiler";
        version = "${version}";
        sha256 = "3427232caf0835f94680e5bcf082408a70b48ad68a5f5c0b02a3bea9f3a075b9";
      };

      beamDeps = [ elixir_make ];
    };

    comeonin = buildMix rec {
      name = "comeonin";
      version = "5.5.1";

      src = fetchHex {
        pkg = "comeonin";
        version = "${version}";
        sha256 = "65aac8f19938145377cee73973f192c5645873dcf550a8a6b18187d17c13ccdb";
      };

      beamDeps = [];
    };

    db_connection = buildMix rec {
      name = "db_connection";
      version = "2.10.2";

      src = fetchHex {
        pkg = "db_connection";
        version = "${version}";
        sha256 = "510b14482330f1af6490a2fa0efd8d4f1435d1529b165647df22ac0f2df0fa93";
      };

      beamDeps = [ telemetry ];
    };

    decimal = buildMix rec {
      name = "decimal";
      version = "3.1.1";

      src = fetchHex {
        pkg = "decimal";
        version = "${version}";
        sha256 = "c5f25f2ced74a0587d03e6023f595db8e924c9d3922c8c8ffd9edfc4498cf1f6";
      };

      beamDeps = [];
    };

    ecto = buildMix rec {
      name = "ecto";
      version = "3.14.1";

      src = fetchHex {
        pkg = "ecto";
        version = "${version}";
        sha256 = "24b991956796700f467d0a3ef3d303138a3ef9ddddf8b98f43758ee067b20a30";
      };

      beamDeps = [ decimal jason telemetry ];
    };

    ecto_sql = buildMix rec {
      name = "ecto_sql";
      version = "3.14.0";

      src = fetchHex {
        pkg = "ecto_sql";
        version = "${version}";
        sha256 = "f4d8d36faf294c9417b5a37ec7ac8217ee2abdef5fcf197ba690f361548d3949";
      };

      beamDeps = [ db_connection decimal ecto postgrex telemetry ];
    };

    elixir_make = buildMix rec {
      name = "elixir_make";
      version = "0.10.0";

      src = fetchHex {
        pkg = "elixir_make";
        version = "${version}";
        sha256 = "dc1f09fb7fa68866b886abd5f0f3c83553b1a19a52359a899e92af1bb3b31982";
      };

      beamDeps = [];
    };

    esbuild = buildMix rec {
      name = "esbuild";
      version = "0.10.0";

      src = fetchHex {
        pkg = "esbuild";
        version = "${version}";
        sha256 = "468489cda427b974a7cc9f03ace55368a83e1a7be12fba7e30969af78e5f8c70";
      };

      beamDeps = [ jason ];
    };

    ex_machina = buildMix rec {
      name = "ex_machina";
      version = "2.8.2";

      src = fetchHex {
        pkg = "ex_machina";
        version = "${version}";
        sha256 = "42f551b2a3a26d138788160d44e391a6bf31266af48125c2b935f24521ebd644";
      };

      beamDeps = [ ecto ecto_sql ];
    };

    expo = buildMix rec {
      name = "expo";
      version = "1.1.1";

      src = fetchHex {
        pkg = "expo";
        version = "${version}";
        sha256 = "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640";
      };

      beamDeps = [];
    };

    file_system = buildMix rec {
      name = "file_system";
      version = "1.1.1";

      src = fetchHex {
        pkg = "file_system";
        version = "${version}";
        sha256 = "7a15ff97dfe526aeefb090a7a9d3d03aa907e100e262a0f8f7746b78f8f87a5d";
      };

      beamDeps = [];
    };

    finch = buildMix rec {
      name = "finch";
      version = "0.23.0";

      src = fetchHex {
        pkg = "finch";
        version = "${version}";
        sha256 = "80e58d3f936f57e3fdf404f83a3642897ae6d9fb642934e46da4d8fe761b99d5";
      };

      beamDeps = [ mime mint nimble_options nimble_pool telemetry ];
    };

    fine = buildMix rec {
      name = "fine";
      version = "0.1.6";

      src = fetchHex {
        pkg = "fine";
        version = "${version}";
        sha256 = "5638eb4495488e885ebec167fa57973e5c35e1a50c344eb7666c90ec1c4e3b12";
      };

      beamDeps = [];
    };

    floki = buildMix rec {
      name = "floki";
      version = "0.38.4";

      src = fetchHex {
        pkg = "floki";
        version = "${version}";
        sha256 = "bdb34645eee8e79845c7edaca2d4099a52804ee4d4a3ecc683a69451f0244973";
      };

      beamDeps = [];
    };

    gettext = buildMix rec {
      name = "gettext";
      version = "1.0.2";

      src = fetchHex {
        pkg = "gettext";
        version = "${version}";
        sha256 = "eab805501886802071ad290714515c8c4a17196ea76e5afc9d06ca85fb1bfeb3";
      };

      beamDeps = [ expo ];
    };

    hpax = buildMix rec {
      name = "hpax";
      version = "1.0.4";

      src = fetchHex {
        pkg = "hpax";
        version = "${version}";
        sha256 = "afc7cb142ebcc2d01ce7816190b98ce5dd49e799111b24249f3443d730f377ca";
      };

      beamDeps = [];
    };

    idna = buildRebar3 rec {
      name = "idna";
      version = "7.1.0";

      src = fetchHex {
        pkg = "idna";
        version = "${version}";
        sha256 = "6ae959a025bf36df61a8cab8508d9654891b5426a84c44d82deaffd6ddf8c71f";
      };

      beamDeps = [];
    };

    jason = buildMix rec {
      name = "jason";
      version = "1.4.5";

      src = fetchHex {
        pkg = "jason";
        version = "${version}";
        sha256 = "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684";
      };

      beamDeps = [ decimal ];
    };

    lazy_html = buildMix rec {
      name = "lazy_html";
      version = "0.1.12";

      src = fetchHex {
        pkg = "lazy_html";
        version = "${version}";
        sha256 = "8a0da594776caee58782c6f93b2abaa5bdb809daf8d43351a561f7de9dc2e2a8";
      };

      beamDeps = [ cc_precompiler elixir_make fine ];
    };

    mime = buildMix rec {
      name = "mime";
      version = "2.0.7";

      src = fetchHex {
        pkg = "mime";
        version = "${version}";
        sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd";
      };

      beamDeps = [];
    };

    mint = buildMix rec {
      name = "mint";
      version = "1.9.3";

      src = fetchHex {
        pkg = "mint";
        version = "${version}";
        sha256 = "5f7c9342480c069dbbc4eeac3490303c9e01870ff01a7f1d29b6107054fc1e74";
      };

      beamDeps = [ hpax ];
    };

    nimble_options = buildMix rec {
      name = "nimble_options";
      version = "1.1.1";

      src = fetchHex {
        pkg = "nimble_options";
        version = "${version}";
        sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
      };

      beamDeps = [];
    };

    nimble_pool = buildMix rec {
      name = "nimble_pool";
      version = "1.1.0";

      src = fetchHex {
        pkg = "nimble_pool";
        version = "${version}";
        sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
      };

      beamDeps = [];
    };

    phoenix = buildMix rec {
      name = "phoenix";
      version = "1.8.9";

      src = fetchHex {
        pkg = "phoenix";
        version = "${version}";
        sha256 = "3477e2dd5a4f61820341169031bdfe21275f659923bea9c5c0ea2aa1c3fcc046";
      };

      beamDeps = [ bandit jason phoenix_pubsub phoenix_template plug plug_crypto telemetry websock_adapter ];
    };

    phoenix_ecto = buildMix rec {
      name = "phoenix_ecto";
      version = "4.7.0";

      src = fetchHex {
        pkg = "phoenix_ecto";
        version = "${version}";
        sha256 = "1d75011e4254cb4ddf823e81823a9629559a1be93b4321a6a5f11a5306fbf4cc";
      };

      beamDeps = [ ecto phoenix_html plug postgrex ];
    };

    phoenix_html = buildMix rec {
      name = "phoenix_html";
      version = "4.3.0";

      src = fetchHex {
        pkg = "phoenix_html";
        version = "${version}";
        sha256 = "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad";
      };

      beamDeps = [];
    };

    phoenix_live_dashboard = buildMix rec {
      name = "phoenix_live_dashboard";
      version = "0.8.7";

      src = fetchHex {
        pkg = "phoenix_live_dashboard";
        version = "${version}";
        sha256 = "3a8625cab39ec261d48a13b7468dc619c0ede099601b084e343968309bd4d7d7";
      };

      beamDeps = [ ecto mime phoenix_live_view telemetry_metrics ];
    };

    phoenix_live_reload = buildMix rec {
      name = "phoenix_live_reload";
      version = "1.7.0";

      src = fetchHex {
        pkg = "phoenix_live_reload";
        version = "${version}";
        sha256 = "dc9f44271aa6fc4ab7797f2aa374ba096ef2c87520586280eb095626b7387a68";
      };

      beamDeps = [ file_system phoenix ];
    };

    phoenix_live_view = buildMix rec {
      name = "phoenix_live_view";
      version = "1.2.8";

      src = fetchHex {
        pkg = "phoenix_live_view";
        version = "${version}";
        sha256 = "b05ffe21f43c0ff219da62948b482c324aa5b8873e17b0c0cac58289a178af38";
      };

      beamDeps = [ jason lazy_html phoenix phoenix_html phoenix_template plug telemetry ];
    };

    phoenix_pubsub = buildMix rec {
      name = "phoenix_pubsub";
      version = "2.2.0";

      src = fetchHex {
        pkg = "phoenix_pubsub";
        version = "${version}";
        sha256 = "adc313a5bf7136039f63cfd9668fde73bba0765e0614cba80c06ac9460ff3e96";
      };

      beamDeps = [];
    };

    phoenix_template = buildMix rec {
      name = "phoenix_template";
      version = "1.0.4";

      src = fetchHex {
        pkg = "phoenix_template";
        version = "${version}";
        sha256 = "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206";
      };

      beamDeps = [ phoenix_html ];
    };

    plug = buildMix rec {
      name = "plug";
      version = "1.20.3";

      src = fetchHex {
        pkg = "plug";
        version = "${version}";
        sha256 = "be266aee1b8536ef6409d58cf39a3121319f0ec47cfa1b24024485aa0e76ad76";
      };

      beamDeps = [ mime plug_crypto telemetry ];
    };

    plug_crypto = buildMix rec {
      name = "plug_crypto";
      version = "2.2.0";

      src = fetchHex {
        pkg = "plug_crypto";
        version = "${version}";
        sha256 = "83a95744ab1c75876542b6fab135fcc176280e0f301a111c1f757fddcec95d2c";
      };

      beamDeps = [];
    };

    postgrex = buildMix rec {
      name = "postgrex";
      version = "0.22.3";

      src = fetchHex {
        pkg = "postgrex";
        version = "${version}";
        sha256 = "f018c13752b2b46e8d35d7e2d84c3276557cbfd880769109021a1d0ee36c1cfe";
      };

      beamDeps = [ db_connection decimal jason ];
    };

    publicist = buildMix rec {
      name = "publicist";
      version = "1.1.0";

      src = fetchHex {
        pkg = "publicist";
        version = "${version}";
        sha256 = "7ed86a54e87e48b7f2fb2d6bb365f0a5e46e987f843494c860dee61c357e2953";
      };

      beamDeps = [];
    };

    styler = buildMix rec {
      name = "styler";
      version = "1.12.2";

      src = fetchHex {
        pkg = "styler";
        version = "${version}";
        sha256 = "a82baeb6d81e35ee1c4cf8af08e141e8d7872a1d442f6fefce29817869e77a01";
      };

      beamDeps = [];
    };

    swoosh = buildMix rec {
      name = "swoosh";
      version = "1.27.0";

      src = fetchHex {
        pkg = "swoosh";
        version = "${version}";
        sha256 = "5da7d3b11de5d61327275ed599cb311942ea6e23cdbb411981f46ee150cddf76";
      };

      beamDeps = [ bandit finch idna jason mime plug telemetry ];
    };

    tailwind = buildMix rec {
      name = "tailwind";
      version = "0.5.1";

      src = fetchHex {
        pkg = "tailwind";
        version = "${version}";
        sha256 = "c4e26302a59fec72abc5610ecb6ad2116d9aa31f31aab2d4b8eb6e95d25a689c";
      };

      beamDeps = [];
    };

    telemetry = buildRebar3 rec {
      name = "telemetry";
      version = "1.4.2";

      src = fetchHex {
        pkg = "telemetry";
        version = "${version}";
        sha256 = "928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1";
      };

      beamDeps = [];
    };

    telemetry_metrics = buildMix rec {
      name = "telemetry_metrics";
      version = "1.1.0";

      src = fetchHex {
        pkg = "telemetry_metrics";
        version = "${version}";
        sha256 = "e7b79e8ddfde70adb6db8a6623d1778ec66401f366e9a8f5dd0955c56bc8ce67";
      };

      beamDeps = [ telemetry ];
    };

    telemetry_poller = buildRebar3 rec {
      name = "telemetry_poller";
      version = "1.3.0";

      src = fetchHex {
        pkg = "telemetry_poller";
        version = "${version}";
        sha256 = "51f18bed7128544a50f75897db9974436ea9bfba560420b646af27a9a9b35211";
      };

      beamDeps = [ telemetry ];
    };

    thousand_island = buildMix rec {
      name = "thousand_island";
      version = "1.5.0";

      src = fetchHex {
        pkg = "thousand_island";
        version = "${version}";
        sha256 = "708923d40523e43cf99041ab37a0d4b0ec426ac6438fa3716ab23d919eaeb412";
      };

      beamDeps = [ telemetry ];
    };

    uxid = buildMix rec {
      name = "uxid";
      version = "2.9.0";

      src = fetchHex {
        pkg = "uxid";
        version = "${version}";
        sha256 = "af4a43db3e9f25b7b182eb1870c712224e9a205f39676d98e6cfaaf3fe6029c1";
      };

      beamDeps = [ ecto ];
    };

    websock = buildMix rec {
      name = "websock";
      version = "0.5.3";

      src = fetchHex {
        pkg = "websock";
        version = "${version}";
        sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
      };

      beamDeps = [];
    };

    websock_adapter = buildMix rec {
      name = "websock_adapter";
      version = "0.6.0";

      src = fetchHex {
        pkg = "websock_adapter";
        version = "${version}";
        sha256 = "50021a85bce8f203b086705d9e0c5415e2c7eb05d319111b0428fe71f9934617";
      };

      beamDeps = [ bandit plug websock ];
    };
  };
in self
