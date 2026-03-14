import SwiftUI
import CryptoKit

struct ProfileAvatarView: View {
    let userName: String
    let userEmail: String
    let size: CGFloat

    @State private var avatarImage: NSImage?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let image = avatarImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didLoad {
                // All strategies failed — programmer icon
                Image(systemName: "laptopcomputer")
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(Color.mkAccent)
            } else {
                // Loading placeholder — letter
                Text(String(userName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color.mkAccent)
            }
        }
        .frame(width: size, height: size)
        .background(Color.mkAccent.opacity(0.25))
        .clipShape(Circle())
        .task(id: userEmail) {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        // Strategy 1: Gravatar via email
        if let image = await fetchImage(from: gravatarURL()) {
            avatarImage = image
            return
        }

        // Strategy 2: GitHub avatar by username
        let ghUsername = userName.replacingOccurrences(of: " ", with: "")
        if let image = await fetchImage(from: "https://github.com/\(ghUsername).png?size=\(Int(size * 2))") {
            avatarImage = image
            return
        }

        // Strategy 3: GitHub API search by email
        if let image = await fetchGitHubAvatarByEmail() {
            avatarImage = image
            return
        }

        didLoad = true
    }

    private func gravatarURL() -> String {
        let trimmed = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = Insecure.MD5.hash(data: Data(trimmed.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "https://www.gravatar.com/avatar/\(hash)?s=\(Int(size * 2))&d=404"
    }

    private func fetchGitHubAvatarByEmail() async -> NSImage? {
        let encoded = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userEmail
        guard let url = URL(string: "https://api.github.com/search/users?q=\(encoded)+in:email") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              let first = items.first,
              let avatarURLString = first["avatar_url"] as? String else { return nil }

        return await fetchImage(from: avatarURLString)
    }

    private func fetchImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let image = NSImage(data: data) else { return nil }

        return image
    }
}
