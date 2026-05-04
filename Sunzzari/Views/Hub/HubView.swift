import SwiftUI

struct HubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.miraclesBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    PageHeader("Hub")

                    ScrollView {
                        VStack(spacing: 16) {
                            NavigationLink(destination: RestaurantHubView()) {
                                HubCardView(title: "Restaurants", subtitle: "Our Favorites", assetName: "hubRestaurants")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: WineHubView()) {
                                HubCardView(title: "Wine", subtitle: "Our Collection", assetName: "hubWine")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: ActivitiesHubView()) {
                                HubCardView(title: "Activities", subtitle: "Things To Do", assetName: "hubActivities")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: TravelView()) {
                                HubCardView(title: "Travel", subtitle: "Our Trips", symbolName: "map.fill")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: GalleryView()) {
                                HubCardView(title: "Gallery", subtitle: "Our Photos", symbolName: "photo.stack.fill")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: OnThisDayView()) {
                                HubCardView(title: "On This Day", subtitle: "Family Memories", symbolName: "calendar.badge.clock")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
