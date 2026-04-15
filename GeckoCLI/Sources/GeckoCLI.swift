import ArgumentParser

@main
struct GeckoCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gecko",
        abstract: "Manage GitHub Issues and Projects from the command line."
    )

    func run() throws {
        print("gecko — GitHub Issues & Projects CLI")
    }
}
