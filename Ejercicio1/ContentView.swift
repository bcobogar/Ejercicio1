//
//  ContentView.swift
//  Ejercicio1
//
//  Created by Beatriz Maria Cobo Garcia on 21/04/2026.
//

import SwiftUI

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
        guard let last = url.split(separator: "/").dropLast().last,
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

// MARK: - ViewModel

@MainActor
final class PokemonListViewModel: ObservableObject {
    @Published var pokemon: [PokemonListItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let baseURL = "https://pokeapi.co/api/v2/pokemon"
    private let limit: Int = 50
    private var offset: Int = 0
    private var canLoadMore: Bool = true

    func fetchInitial() {
        guard pokemon.isEmpty else { return }
        offset = 0
        canLoadMore = true
        pokemon.removeAll()
        fetchPokemon()
    }

    func fetchMoreIfNeeded(currentItem item: PokemonListItem?) {
        guard let item else { return }
        let thresholdIndex = pokemon.index(pokemon.endIndex, offsetBy: -5)
        if pokemon.firstIndex(where: { $0.id == item.id }) == thresholdIndex {
            fetchPokemon()
        }
    }

    func fetchPokemon() {
        guard !isLoading, canLoadMore else { return }

        isLoading = true
        errorMessage = nil

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
                pokemon.append(contentsOf: decoded.results)
                offset += limit
                canLoadMore = decoded.next != nil
            } catch {
                errorMessage = "Error al cargar Pokémon: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Views

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
                    List {
                        ForEach(viewModel.pokemon) { pokemon in
                            PokemonRowView(pokemon: pokemon)
                                .task {
                                    viewModel.fetchMoreIfNeeded(currentItem: pokemon)
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
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
