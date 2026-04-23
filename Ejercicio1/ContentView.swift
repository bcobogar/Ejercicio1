//
//  ContentView.swift
//  Ejercicio1
//
//  Created by Beatriz Maria Cobo Garcia on 21/04/2026.
//

import SwiftUI
internal import Combine

// MARK: - Models

struct PokemonListResponse: Decodable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [PokemonListItem]
}

struct PokemonListItem: Decodable, Identifiable {
    let name: String
    let url: String

    var id: Int {
        // URL format: https://pokeapi.co/api/v2/pokemon/{id}/
        guard let last = url.split(separator: "/").last,
              let intId = Int(last) else {
            return UUID().hashValue
        }
        return intId
    }

    var capitalizedName: String {
        name.capitalized
    }

    var imageURL: URL? {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")
    }
}

struct PokemonDetail: Decodable {
    struct PokemonTypeEntry: Decodable {
        struct TypeInfo: Decodable {
            let name: String
        }
        let type: TypeInfo
    }

    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let sprites: Sprites
    let types: [PokemonTypeEntry]

    struct Sprites: Decodable {
        let front_default: String?
    }
    
    var capitalizedName: String {
        name.capitalized
    }

    var imageURL: URL? {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id.self).png")
    }
}

    


// MARK: - ViewModel

@MainActor
final class PokemonListViewModel: ObservableObject {
    @Published var pokemon: [PokemonListItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let baseURL = "https://pokeapi.co/api/v2/pokemon"
    private let limit: Int = 50
    private(set) var currentPage: Int = 0
    private var canLoadMore: Bool = true

    var hasNextPage: Bool {
        canLoadMore
    }

    var hasPreviousPage: Bool {
        currentPage > 0
    }

    func fetchInitial() {
        loadPage(0)
    }

    func loadPage(_ page: Int) {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        let offset = page * limit

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components.url else {
            isLoading = false
            errorMessage = "URL inválida"
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    throw URLError(.badServerResponse)
                }

                let decoded = try JSONDecoder().decode(PokemonListResponse.self, from: data)
                await MainActor.run {
                    self.pokemon = decoded.results
                    self.currentPage = page
                    self.canLoadMore = decoded.next != nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error al cargar Pokémon: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    func goToNextPage() {
        guard hasNextPage else { return }
        loadPage(currentPage + 1)
    }

    func goToPreviousPage() {
        guard hasPreviousPage else { return }
        loadPage(currentPage - 1)
    }
}

// MARK: - Views

@MainActor final class PokemonDetailViewModel: ObservableObject {
    @Published var detail: PokemonDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func fetchDetail(for pokemon: PokemonListItem) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        guard let url = URL(string: pokemon.url) else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "URL de detalle inválida"
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(PokemonDetail.self, from: data)
            await MainActor.run {
                self.detail = decoded
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error al cargar detalle: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }
}

struct PokemonDetailView: View {
    let pokemon: PokemonListItem
    @StateObject private var viewModel = PokemonDetailViewModel()

    var body: some View {
        ScrollView {
            Group {
                if viewModel.isLoading && viewModel.detail == nil {
                    ProgressView("Cargando detalle...")
                        .padding()
                } else if let error = viewModel.errorMessage, viewModel.detail == nil {
                    VStack(spacing: 12) {
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Reintentar") {
                            Task {
                                await viewModel.fetchDetail(for: pokemon)
                            }
                        }
                    }
                    .padding()
                } else if let detail = viewModel.detail {
                    VStack(spacing: 16) {
                        if let spriteURL = URL(string: detail.sprites.front_default ?? "") {
                            AsyncImage(url: spriteURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    Image(systemName: "questionmark.square.dashed")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        Text(detail.name.capitalized)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("#\(detail.id)")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tipos")
                                .font(.headline)

                            HStack {
                                ForEach(detail.types, id: \.type.name) { entry in
                                    Text(entry.type.name.capitalized)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(color(forType: entry.type.name))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 24) {
                            VStack {
                                Text("Altura")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                // PokeAPI: height en decímetros
                                Text("\(Double(detail.height) / 10, specifier: "%.1f") m")
                                    .font(.headline)
                            }

                            VStack {
                                Text("Peso")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                // PokeAPI: weight en hectogramos
                                Text("\(Double(detail.weight) / 10, specifier: "%.1f") kg")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(pokemon.capitalizedName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchDetail(for: pokemon)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PokemonListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.pokemon.isEmpty {
                    ProgressView("Cargando Pokémon...")
                } else if let error = viewModel.errorMessage, viewModel.pokemon.isEmpty {
                    VStack(spacing: 12) {
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Reintentar") {
                            viewModel.fetchInitial()
                        }
                    }
                    .padding()
                } else {
                    VStack {
                        List {
                            ForEach(viewModel.pokemon) { pokemon in
                                NavigationLink {
                                    PokemonDetailView(pokemon: pokemon)
                                } label: {
                                    PokemonRowView(pokemon: pokemon)
                                }
                            }

                            if let error = viewModel.errorMessage {
                                Section {
                                    VStack(spacing: 8) {
                                        Text(error)
                                            .font(.footnote)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                        Button("Reintentar") {
                                            viewModel.loadPage(viewModel.currentPage)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                            }

                            if viewModel.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            }
                        }
                        .listStyle(.plain)

                        HStack {
                            Button("Anterior") {
                                viewModel.goToPreviousPage()
                            }
                            .disabled(!viewModel.hasPreviousPage || viewModel.isLoading)

                            Spacer()

                            Text("Página \(viewModel.currentPage + 1)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("Siguiente") {
                                viewModel.goToNextPage()
                            }
                            .disabled(!viewModel.hasNextPage || viewModel.isLoading)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Pokédex")
            .task {
                viewModel.fetchInitial()
            }
        }
    }
}

struct PokemonRowView: View {
    let pokemon: PokemonListItem

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: pokemon.imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 56, height: 56)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Image(systemName: "questionmark.square.dashed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pokemon.capitalizedName)
                    .font(.headline)
                Text("#\(pokemon.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .padding(.vertical, 4)
    }
}

private func color(forType type: String) -> Color {
    switch type.lowercased() {
    case "fire":
        return Color.red.opacity(0.7)
    case "water":
        return Color.blue.opacity(0.7)
    case "grass", "bug":
        return Color.green.opacity(0.7)
    case "electric":
        return Color.yellow.opacity(0.7)
    case "poison", "ghost":
        return Color.purple.opacity(0.7)
    case "psychic", "fairy":
        return Color.pink.opacity(0.7)
    case "rock", "ground":
        return Color.brown.opacity(0.7)
    case "ice":
        return Color.cyan.opacity(0.7)
    case "fighting":
        return Color.orange.opacity(0.7)
    case "dragon":
        return Color.indigo.opacity(0.7)
    case "steel":
        return Color.gray.opacity(0.7)
    case "normal":
        return Color(.systemGray4)
    default:
        return Color.blue.opacity(0.2)
    }
}

#Preview {
    ContentView()
}
