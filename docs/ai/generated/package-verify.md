# Package verify

- Status: `failed`
- Generated at: `2026-05-10T10:33:08+00:00`
- Commit: `06dde0c`
- Branch: `codex/integrate-ai-search-scripts-into-project`
- Recommended next action: `Refresh lock or revert unintended template drift.`

```json
{
    "schema_version": 1,
    "artifact": "package-verify.json",
    "generated_at": "2026-05-10T10:33:08+00:00",
    "command": "php tools/ai/ai.php package-verify",
    "based_on_commit": "06dde0c",
    "based_on_branch": "codex/integrate-ai-search-scripts-into-project",
    "input_hashes": {},
    "status": "failed",
    "score": null,
    "stale": false,
    "recommended_next_action": "Refresh lock or revert unintended template drift.",
    "data": {
        "path": "packages/ai-universal-rules/package-lock.ai.json",
        "mismatch_count": 84,
        "mismatches": [
            {
                "path": "templates/all_into_one.bat",
                "reason": "missing_from_lock",
                "current": "sha256:c75c73b695acf6ed616fe24b658f672664cbcdc36ee859f32c7c2104fcb1d2b7"
            },
            {
                "path": "templates/capabilities/README.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:7bf541be81cc1f0cb92868b089ff0f94c891175b67dac82220954081564f8919",
                "current": "sha256:af095a83602f45b79003a86911d13867cc704315c024f57350d09042a4650be6"
            },
            {
                "path": "templates/capabilities/bug-regression/checklist.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:c7a0d73e57137448939ffba4e36e03e39e353cf0d7dfe041cf7e42468b09005c",
                "current": "sha256:8801fa62bf5959c7b54b09497ce989443ce6e082c50520f62531c4e04022ac73"
            },
            {
                "path": "templates/capabilities/bug-regression/config.example.json",
                "reason": "checksum_mismatch",
                "expected": "sha256:c78a19f96f70f93b95e32afaa84ad0d9b582da30f382af16278f2e896ce74642",
                "current": "sha256:750d453b0f63981f1c725925b38e7b31515617aab680abcc437fbe19ca7a182b"
            },
            {
                "path": "templates/capabilities/bug-regression/examples.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:8a1a081fb9c9dac6f3b4380132f718fcf989a279448f90ff2dc5c0b677b1ea59",
                "current": "sha256:cbcc7988293e43aae3463d3461d5dd303318acdd0e925336a3ae9aab444b49d3"
            },
            {
                "path": "templates/capabilities/bug-regression/gotchas.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:1ef3c87b019975a13544bcac8bae8685cdf946e4d416384138b802a953d6da65",
                "current": "sha256:0e34ea82bd3f2f08b9fbd17cd5742cfc6331a964d1fa1bb7a3b2c54fe9458249"
            },
            {
                "path": "templates/capabilities/bug-regression/reference.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:966be588b9736f6b44a8ea7c76c6849cb8c7d6ece87dbf5a0afffc19fe6cd374",
                "current": "sha256:34eddea65611144521775c0386ab841c247f8133b1f868dce499472856e69028"
            },
            {
                "path": "templates/capabilities/dependency-upgrade/checklist.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:aaecef1d0e53546c6fe2d6d238aca1b02008aa89f1466de8c4599ae9fbb8b657",
                "current": "sha256:6cb91c23904d2d5a065b407e8e10be8bcd71be0d3761d5d0924d26777964e612"
            },
            {
                "path": "templates/capabilities/dependency-upgrade/examples.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:b9c1ddc010da73040ddf7062e2dc6fa40e0c2db172368aa393056a78a749ca10",
                "current": "sha256:5908ea7bec4359f63c089f8049c8e664fb747c9d5566763ba5052eb13c9d8bcb"
            },
            {
                "path": "templates/capabilities/dependency-upgrade/gotchas.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:7cc4dfbae2f448a794bd5982bd01d84ebfaa70f831e912073d365e9b091c0233",
                "current": "sha256:f16dadb90caf0fc764abbc87a35fcc47564c674d9984e4adcac3471fb0dd9292"
            },
            {
                "path": "templates/capabilities/dependency-upgrade/reference.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:bb618935a58c58acff831274e86fd2db52f3282d4fc2bbfce653b985c5459f03",
                "current": "sha256:ab8b1e7381f4dbf78850b109c36af31e31b149d6fec622ef50fd99337dc77d1c"
            },
            {
                "path": "templates/capabilities/evidence-first-execution/CAPABILITY.md",
                "reason": "missing_from_lock",
                "current": "sha256:e955ea10bf4dc29e4f45bd49ff81f6e3ead161d7a8058a0782516573d8cc5f9a"
            },
            {
                "path": "templates/capabilities/evidence-first-execution/checklist.md",
                "reason": "missing_from_lock",
                "current": "sha256:c51c0d4afc5de7df2bfcc52fae552770b96a3e634608ee4cd46bb993a890c016"
            },
            {
                "path": "templates/capabilities/evidence-first-execution/examples.md",
                "reason": "missing_from_lock",
                "current": "sha256:ed706531663407884cb8b01c60eec4e3bce53fad7ce31b5b13f892dadfaa1609"
            },
            {
                "path": "templates/capabilities/evidence-first-execution/gotchas.md",
                "reason": "missing_from_lock",
                "current": "sha256:481740b010ad68f1c7f11588ee84c7c729daf0aa344c5f290e0caa374d13755e"
            },
            {
                "path": "templates/capabilities/evidence-first-execution/reference.md",
                "reason": "missing_from_lock",
                "current": "sha256:67d59094cec966a76957b3b1ab60a5101afa6b9bf01101397a3d0819923fdbb8"
            },
            {
                "path": "templates/capabilities/project-context/CAPABILITY.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:f00c067b68dc3141725e3266634546379756720fb0958687d3606797b9695a6e",
                "current": "sha256:e62dc7334a6a0e64d44c29e35d39338ab102dcb7ade80aa42f129024532b46f3"
            },
            {
                "path": "templates/capabilities/project-context/examples.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:d02cbc4930f4ee4655a243d2bbd6d5819b9964d845abfab5c08f3a677f4158b3",
                "current": "sha256:a8b67224c2c43f0e3a2568a4c1017603b52c4bc2415a2eff06a98a9ad6ca1241"
            },
            {
                "path": "templates/capabilities/project-context/gotchas.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:64dfa273a78a42eeda8b6d86a7cfe7ab77ec3282b6a4e55a750e3566f539dfe8",
                "current": "sha256:9471a3c4982160b642a8b5403f1cdf5ae03a68307e311a88b51e31c5dbc0272a"
            },
            {
                "path": "templates/capabilities/project-context/reference.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:0b1bb6c37e0e32a686fea1bc54720bd58138d787a0bca8d4212e5e34404655a9",
                "current": "sha256:70f6574d08d5731e2b075cb197b2a104e00595ec7f88657ba00d0d3d34b1d279"
            },
            {
                "path": "templates/capabilities/release-safety/checklist.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:d353c8616157621a32a006df57e887248ec4d3566e8d088000b5bb6aec20a8df",
                "current": "sha256:b03fe0c59c6c8ab1b150f9af9258910230238414feb5810be6c7ac6f0d10c391"
            },
            {
                "path": "templates/capabilities/release-safety/examples.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:ff0aac01bdd83272682c080e704b4e0204977cc9e08a779206013140ff091c40",
                "current": "sha256:f61d6b8452331fb6e8fb6bebc03fdddba5edaeb43e74c60a7d8d7f86d124c593"
            },
            {
                "path": "templates/capabilities/release-safety/gotchas.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:1bf0e1ba6772f6a2e83136ed277ef27770bbeb30c558ca90fcd0d47e53123fa4",
                "current": "sha256:6790cd3616a09a8f3133a73897d9e3fba757f4dbe64b4c247342f21cd7581381"
            },
            {
                "path": "templates/capabilities/release-safety/reference.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:c19b553473a445832865bbcc4fd1f6b0ae3819e0175e839cfe2484b138db49a7",
                "current": "sha256:e5e19d07fef4d2c7f4962122f7f7551ca28a684dd1c75a21e189bda4260e5269"
            },
            {
                "path": "templates/capabilities/review-diff/checklist.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:1b42478be939a6eb82ddc34d2c540364bea8cb24f6dd8a13c5f5014dab1884bc",
                "current": "sha256:6cda68c78068b2ef924f871e2f38e5d527c9821900c2f5679048488702aa6675"
            },
            {
                "path": "templates/capabilities/review-diff/examples.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:a05c23a3a9a577b49ddd1abb98d04e32fa4eda79f6f54f57d0bac7d4ff2cf72e",
                "current": "sha256:d7a5c5ad153d731a0f75a93bbc695780d273736f03230249b9f1e4c216efa04c"
            },
            {
                "path": "templates/capabilities/review-diff/gotchas.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:66fee90942726ca1dc9d96f8022c4244f3e50200e622a8de0ea6e0411515c200",
                "current": "sha256:358fc515413a520f4df51f7a7ec11c29c36637efc9d3709e5970b70348a7bf50"
            },
            {
                "path": "templates/capabilities/review-diff/reference.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:0848debba82a70bb627d6a5d456722bb42a51f9a9e3a51f8fc8ba0c3f8f58d71",
                "current": "sha256:e128240d362df8ebb7f52408b03af166551c1a30bd54fe896f278b0278b19724"
            },
            {
                "path": "templates/capabilities/verify-change/checklist.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:c66c7ec6ee61bb6f0735613f0199d4700326f4901e85bb3f12ba1de524050ed8",
                "current": "sha256:160996728df4d604946fce396e39e7f900bfb0f62fec2aad5d12bb57528e200c"
            },
            {
                "path": "templates/capabilities/verify-change/examples.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:91a0fc23ccdd9d815ee4081d9b5166b15dca2d7c1c17767f4ae78313bf4d3037",
                "current": "sha256:07629bdfe4ffbea9e421d1f7c12dbe1589d30b43f4eff4a64fbaf15226542d05"
            },
            {
                "path": "templates/capabilities/verify-change/gotchas.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:b48d76a394c0856d9365a174528e7578890ffffc12bef96f0fb0791e9f4f2257",
                "current": "sha256:55e9405b4b2d4855d68f56bb4700bccd3b2413f3e3bbdbfc49b72d4ffa73b06d"
            },
            {
                "path": "templates/capabilities/verify-change/reference.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:8f56c94b997632da3efa72093bb22d33c40d6bce60528f1a8960b7a5f3f438a2",
                "current": "sha256:6a2bffa6316d0d68397d986fe955240a9a6d955a999748a1f79b54f494702c73"
            },
            {
                "path": "templates/commands/search-evidence.md",
                "reason": "missing_from_lock",
                "current": "sha256:12c812fa848ff921f53338a5ca8dca63624541a8f7f2cf866c8d471bbaf71f6c"
            },
            {
                "path": "templates/commands/verify-ai-wiring.md",
                "reason": "missing_from_lock",
                "current": "sha256:0ef10becc738132ae34fc1d996e1ae3aa9a75f86746cf3c3c002ee6517e5e45a"
            },
            {
                "path": "templates/core/AGENTS.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:50195d531092f310fc6c356017ebea24d72910ce556b4485dc61cb1e8726c6a8",
                "current": "sha256:dcaa16beffbdf94457eb3abb4debac2de39647c3fb0c91671ed86dc8fd8ff77a"
            },
            {
                "path": "templates/core/agents/all_into_one.bat",
                "reason": "missing_from_lock",
                "current": "sha256:c75c73b695acf6ed616fe24b658f672664cbcdc36ee859f32c7c2104fcb1d2b7"
            },
            {
                "path": "templates/core/agents/architect.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:9fbfdd205ae0af38675dc6ec988e9fa300151a6f4029d5c39b12de2c9fa20b7d",
                "current": "sha256:719ed4ed936a4618fdf77d97e49e2d35765333c6ea6170bc4e2972fc9edd60ad"
            },
            {
                "path": "templates/core/agents/config-maintainer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:66058beb3b1703e7c98846daaa20a6fb2f188ece867c3a787859f3c4285d46f9",
                "current": "sha256:dc955602ce8bd02715cbef0b7a8c8067e4da0cd699b20df89645709005184e59"
            },
            {
                "path": "templates/core/agents/implementer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:c52f15deed38994be00cffd4ae4bdd3dc7a3f0bf95f794d852bfe325e94c3e07",
                "current": "sha256:84dbdb706035c6bad2595299556f3cc92f01d919abc770f029270629e682736d"
            },
            {
                "path": "templates/core/agents/refactorer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:64c5ea6b70b812f4b7996801cc402006984b4ffc1fc424975b0c21f720f8e169",
                "current": "sha256:53c5f3abc17227a47fafd37746c9094b6c419641e0cb608a07aac7c865f51a5e"
            },
            {
                "path": "templates/core/agents/release-auditor.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:2df0c8fec017045ce3973781d75cd42a123a9eb505a58159ec252c7e7376a579",
                "current": "sha256:e0864d53f16513cba429434cbfed2593931fb7e21c24e55c56e695058ec16a45"
            },
            {
                "path": "templates/core/agents/repository-researcher.md",
                "reason": "missing_from_lock",
                "current": "sha256:c9c7019f995510848eb3fd7673ad9464c0d99ad8b26debfaf99d3b03666646fa"
            },
            {
                "path": "templates/core/agents/repository-reviewer.md",
                "reason": "missing_from_lock",
                "current": "sha256:cb7c3041041c7ff942156f99c625f21d987f6d2ff903f77526a454da236f3547"
            },
            {
                "path": "templates/core/agents/researcher.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:325da9eacc073aeaef0de76f9bb2a78512688afce8aabc7e9936d417f726d7ae",
                "current": "sha256:765084820044e1fc7429dca8776c15dc5171f9c79a82613707b284f40ed121da"
            },
            {
                "path": "templates/core/agents/reviewer.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:944a1e40a4e4ab50e135225a282e57fd5e0216916a4540f0968fae37753a2336",
                "current": "sha256:337130afadde0b3142b845d11317414249e663b5dd42688d7de18bcdb43babfe"
            },
            {
                "path": "templates/core/agents/workflow-auditor.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:632141c88cadc418e4f6d1f593602f60ca8d51e2d27acfaa37275b834e056651",
                "current": "sha256:4799a8f5d238deff73c23655648d6f438933961964798e94f632ebd82799416a"
            },
            {
                "path": "templates/core/ai-file-standards.template.md",
                "reason": "missing_from_lock",
                "current": "sha256:9b734a13faad34825a20bdaa791ead01440fc3e0cdfc137e7c976839ae4dc6e4"
            },
            {
                "path": "templates/core/copilot-instructions.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:8dad01e564d810eba9121de204a5de9c50d7d0316a569ed7674bfc6bda816352",
                "current": "sha256:28097c7baa630daf826d8bad14b7e8cc4d0eb1f87ffdbcad6ec044343f85f8db"
            },
            {
                "path": "templates/core/execution-protocol.template.md",
                "reason": "missing_from_lock",
                "current": "sha256:64aa95d9d704afec150f82e9a6eaf8acaed7e552f4a8b6816d9691adf33f7c3e"
            },
            {
                "path": "templates/core/opencode.json",
                "reason": "missing_from_lock",
                "current": "sha256:f2e9fc76a5cec97cb7bda7b099344d592b27831b5e34dce600cf7a7f47e50f3c"
            },
            {
                "path": "templates/core/project-stack.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:b3f8c3d19d9b07257f242d10290adf7ce3b4f48ee5b45d4c5044cc5ba308ba0c",
                "current": "sha256:9fd1e0f2a0e4c9ebd4c174bec6295aad6f4c2360a42f42e8169058555a7a7263"
            },
            {
                "path": "templates/core/workflow.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:a93a7ce58c226f5cc609e4445dac0180b5076941aed185d0f02d7adb2098bb5d",
                "current": "sha256:da9e5e7c32ceb06f986f7119e85296df6b41c016f0a43b4fc1765a96dec57fce"
            },
            {
                "path": "templates/docs/ai/tools/actions/preview-file.md",
                "reason": "missing_from_lock",
                "current": "sha256:0c97a1f4cfb371ce2acd775402044e1bb3c856cf12cda7405d95eaf6f4303aca"
            },
            {
                "path": "templates/github/pull_request_template.md",
                "reason": "missing_from_lock",
                "current": "sha256:2e68235300df539f2ac81823ecfbfe13bcef97de94b4fcc20b0a76c18143f937"
            },
            {
                "path": "templates/github/workflows/export-ai-universal-rules-preview.yml",
                "reason": "missing_from_lock",
                "current": "sha256:e313eac2506c4678e25af25e87761cc93e3cb4cccfa39df41fdc8fd0055dde1d"
            },
            {
                "path": "templates/github/workflows/test-external-install.yml",
                "reason": "missing_from_lock",
                "current": "sha256:f421dbb03045a38de645f4e4954c639344e3c74487ce425d7818ed775be14b5d"
            },
            {
                "path": "templates/github/workflows/validate-ai-surface.yml",
                "reason": "missing_from_lock",
                "current": "sha256:61b96fbbc6ba064eb48b52ffb8a74929cbcabe67e0b7b2589d11eca4bf8238b3"
            },
            {
                "path": "templates/instructions/ALL_IN_ONE.txt",
                "reason": "missing_from_lock",
                "current": "sha256:4a54c222584034efda25ce734c4fce626251af8a12c5188f0cf076a8902c4923"
            },
            {
                "path": "templates/instructions/ai-file-standards.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:8eea13c4f6763cccc97f225d8d4c2a16c6b95302ec25b22c44d581a6f6ad84c9"
            },
            {
                "path": "templates/instructions/ai-search.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:b7cce500a99a5979287153884ce8ad2ef893ddd242581d96940f837e564477a9"
            },
            {
                "path": "templates/instructions/ai-tooling.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:f0b9626c6c382b1609c100885cbdbdc2fa6a955bb64beea04e12b2bdf4046a4f"
            },
            {
                "path": "templates/instructions/ai-tools.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:0a200e7b7d14de7fc2927b73dbdc6b6a4195e93358b6d2967690f88fc726e4fe"
            },
            {
                "path": "templates/instructions/all_into_one.bat",
                "reason": "missing_from_lock",
                "current": "sha256:c75c73b695acf6ed616fe24b658f672664cbcdc36ee859f32c7c2104fcb1d2b7"
            },
            {
                "path": "templates/instructions/approval-boundaries.instructions.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:7c7edcfbe828cadae7d947d1d6d191ebbf6859d85087ad9e4d1a2ce8139809e7",
                "current": "sha256:7fc230b64fbc2f8a8fdf379afd37224a17ee4bfb71e50fa295beb2539c594c75"
            },
            {
                "path": "templates/instructions/base.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:b51ad4ea224a3c9da014cd63454f5c7ce363b3fc9a7e017089ec0daacb2be8a2"
            },
            {
                "path": "templates/instructions/ci-workflows.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:b8bfad551811311df0ce3375f73cd00989a27b26dd42ef94afe0e19c688f0e10"
            },
            {
                "path": "templates/instructions/composer.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:7f0bf0fee33763b40e958fbc8acebc21387c0399e552d427e2ee72e9a563f609"
            },
            {
                "path": "templates/instructions/config-infra.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:e846fa06e071665c0de184c849511f36621458acf10c968980a17bed0e3eb462"
            },
            {
                "path": "templates/instructions/execution-protocol.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:1563dd73faaba5feceed7abe449a9ef20f20e40e559f71e2fa7f760cde898fa7"
            },
            {
                "path": "templates/instructions/generated-artifacts.instructions.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:afc4aedab347a98bd6375db7213644d04fe701a2dfd96726a83d5dcb86632974",
                "current": "sha256:2b0ff13836b5b4e5806de053e28ec096997df758ea9d2432711ab1584e79cf57"
            },
            {
                "path": "templates/instructions/php.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:35bf0edab9ee873a7a90d4ed6abd7600c6d1e19ebadebf70a68c1ee8ec78ba6f"
            },
            {
                "path": "templates/instructions/security.instructions.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:8e8e116dab202843d0f94ee4ae8bc27c0676f2790920b7eff7e28e3636e56905",
                "current": "sha256:916e6be35a3b8f8e9df62dd999f64b70540972f97e72d0ab03a06fff45aa616e"
            },
            {
                "path": "templates/instructions/shell.instructions.md",
                "reason": "missing_from_lock",
                "current": "sha256:364783597c2999a7271c16eb6e48dc20f3040436200d3870131ce5e3090f6f80"
            },
            {
                "path": "templates/optional/delivery/README.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:1c167735dd80af27b7961ae6ed46ae9f8f45d8ef64238423fab6b979a3c6b48a",
                "current": "sha256:77a075656341540aa97ad9e6e07b540e0c49e49526043b20130a4828f4629926"
            },
            {
                "path": "templates/optional/delivery/slice-card.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:84bdc304b082c9d383aef991130165631f09e1d2aa3f510f47d293a00ab46d7e",
                "current": "sha256:dad9110f3689eb32ad1305292700b5479da60e44855efec226ff1996625746f7"
            },
            {
                "path": "templates/shared/approvals/APPROVAL-PACKET.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:b027b103a5874a2c4821a855df89057af2e2ca6b45d6e43ed9d46ce94b96cf81",
                "current": "sha256:76d01acf8a628a5f49025796bdfc08286cda0837ee208d21cb18f7883d55e228"
            },
            {
                "path": "templates/shared/verification/VERIFICATION-EVIDENCE.template.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:43a3496d6abf3e3e4ad1fc804ccd91ff255fa034c4d54f7c9914feb84a2eab8b",
                "current": "sha256:6b3d82a161cdd4b92c4cf96c70a8ee3d971b676554d71e6bbcd0d70ce2c2f4fc"
            },
            {
                "path": "templates/skills/ai-search/SKILL.md",
                "reason": "missing_from_lock",
                "current": "sha256:77f82bde01f4beeafe20d796a83c3e9bd037f8d86c738555d31a792ef2e02d48"
            },
            {
                "path": "templates/snippets/approvals.snippet.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:81b6f877013a55db9d04f23fbf113fd08a193daf920883061933d3e554ff375e",
                "current": "sha256:dcf3242f36ec43d7940e23bb94f80d126c0690434c1a70c8c5336333d2bee340"
            },
            {
                "path": "templates/snippets/verification.snippet.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:411dde56f27380875a05c1d466cda7262e359e01ef1f69e75ff574d42cc08ab8",
                "current": "sha256:4a43cca30d8db27ead76f1cda8316ff4d0e39a28237849894d131a0e1aecfa2c"
            },
            {
                "path": "templates/snippets/workflow.snippet.md",
                "reason": "checksum_mismatch",
                "expected": "sha256:c96f247e4ab13e56d217a50e8171cd1143a66a27411a0d28a5251066898b3a3d",
                "current": "sha256:7162103f162a531f28b09bfbd07b9c3b7223a98991e2a720ed34ddaf268be4ec"
            },
            {
                "path": "templates/workflows/evidence-first-execution.md",
                "reason": "missing_from_lock",
                "current": "sha256:021511d52df552ce7f9104b8682a0e0eab65b30d2783c4dffdf0b6ee09bdf707"
            },
            {
                "path": "templates/workflows/review-search-tool.md",
                "reason": "missing_from_lock",
                "current": "sha256:f3cd98e84c00b571c4e57611d5633deb3f4e7a3ccefcebbb1c875b1dfd583d80"
            },
            {
                "path": "templates/workflows/search-evidence.md",
                "reason": "missing_from_lock",
                "current": "sha256:1802be31ff935d105d1466094e252ce888da4bcb589b7c87e4a9a4d0fa945bee"
            }
        ]
    }
}
```
