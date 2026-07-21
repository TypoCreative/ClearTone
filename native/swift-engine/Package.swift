// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClearToneEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClearToneEngine", targets: ["ClearToneEngine"])
    ],
    targets: [
        .target(
            name: "CRNNoise",
            path: "Sources/CRNNoise",
            exclude: ["include"],
            sources: [
                "denoise.c",
                "kiss_fft.c",
                "pitch.c",
                "celt_lpc.c",
                "rnn.c",
                "nnet.c",
                "nnet_default.c",
                "rnnoise_tables.c",
                "rnnoise_data.c",
                "parse_lpcnet_weights.c"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("RNNOISE_BUILD"),
                .headerSearchPath("."),
            ]
        ),
        .executableTarget(
            name: "ClearToneEngine",
            dependencies: ["CRNNoise"],
            path: "Sources/ClearToneEngine"
        )
    ]
)
