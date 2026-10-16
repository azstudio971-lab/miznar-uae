import SwiftUI

/// شبكة اختصارات المواقع (الصفحة الرئيسية لقسم الترفيه)
struct ShortcutsGridView: View {
    @ObservedObject private var shortcuts = ShortcutStore.shared
    let onOpen: (URL) -> Void
    let onSendToCar: (URL) -> Void
    let onAdd: () -> Void
    let onEdit: (SiteShortcut) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(shortcuts.shortcuts) { item in
                    Button { onOpen(item.url) } label: { ShortcutTile(item: item) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { onSendToCar(item.url) } label: { Label(tr("فتح في السيارة", "Open in car"), systemImage: "car") }
                            Button { onEdit(item) } label: { Label(tr("تعديل", "Edit"), systemImage: "pencil") }
                            Button(role: .destructive) { shortcuts.remove(item.id) } label: {
                                Label(tr("حذف", "Delete"), systemImage: "trash")
                            }
                        }
                }
                Button(action: onAdd) {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .frame(width: 62, height: 62)
                            .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.white))
                        Text(tr("إضافة", "Add"))
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 40)

            Text(tr("اضغط مطولاً على أي موقع لتعديله أو فتحه في السيارة",
                    "Long-press a site to edit it or open it in the car"))
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal)
        }
    }
}

struct ShortcutTile: View {
    let item: SiteShortcut

    var body: some View {
        VStack(spacing: 8) {
            ShortcutIcon(item: item, size: 62)
            Text(item.name)
                .font(.footnote)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

struct ShortcutIcon: View {
    let item: SiteShortcut
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Color(uiColor: UIColor(hex: item.colorHex)))
            .frame(width: size, height: size)
            .overlay {
                AsyncImage(url: Favicon.url(for: item.url)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(size * 0.2)
                    } else {
                        Text(String(item.name.prefix(1)))
                            .font(.system(size: size * 0.42, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
    }
}

// MARK: - إضافة / تعديل اختصار

struct ShortcutDraft: Identifiable {
    let id = UUID()
    var editingID: UUID?
    var name = ""
    var url = ""
    var colorHex = ShortcutStore.palette.first ?? "#013748"

    init() {}

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    init(editing shortcut: SiteShortcut) {
        editingID = shortcut.id
        name = shortcut.name
        url = shortcut.url.absoluteString
        colorHex = shortcut.colorHex
    }
}

struct ShortcutEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ShortcutDraft

    init(draft: ShortcutDraft) {
        _draft = State(initialValue: draft)
    }

    private var resolvedURL: URL? { URLInput.resolve(draft.url, allowSearch: false) }
    private var colors: [String] { ["#013748", "#FEB13B", "#FF0000", "#111111"] + ShortcutStore.palette }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let url = resolvedURL {
                            ShortcutIcon(item: SiteShortcut(name: draft.name.isEmpty ? (url.host ?? "?") : draft.name,
                                                            url: url, colorHex: draft.colorHex), size: 72)
                        } else {
                            RoundedRectangle(cornerRadius: 17).fill(Color(uiColor: UIColor(hex: draft.colorHex)))
                                .frame(width: 72, height: 72)
                        }
                        Spacer()
                    }
                }
                Section {
                    TextField(tr("الاسم (مثال: شاهد)", "Name (e.g. Shahid)"), text: $draft.name)
                    TextField(tr("الرابط (مثال: shahid.mbc.net)", "Link (e.g. shahid.mbc.net)"), text: $draft.url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(tr("يظهر الاختصار في الهاتف وفي CarPlay.", "The shortcut appears on iPhone and in CarPlay."))
                }
                Section(tr("لون الأيقونة", "Icon color")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Array(Set(colors)).sorted(), id: \.self) { hex in
                            Circle()
                                .fill(Color(uiColor: UIColor(hex: hex)))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Color.primary, lineWidth: draft.colorHex == hex ? 3 : 0))
                                .onTapGesture { draft.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(draft.editingID == nil ? tr("إضافة اختصار", "Add shortcut") : tr("تعديل الاختصار", "Edit shortcut"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("حفظ", "Save"), action: save)
                        .disabled(resolvedURL == nil)
                }
            }
        }
    }

    private func save() {
        guard let url = resolvedURL else { return }
        let title = draft.name.trimmingCharacters(in: .whitespaces)
        let name = title.isEmpty ? (url.host ?? "موقع") : title
        if let id = draft.editingID {
            ShortcutStore.shared.update(SiteShortcut(id: id, name: name, url: url, colorHex: draft.colorHex))
            AppState.shared.showToast(tr("تم حفظ التعديل", "Changes saved"))
        } else {
            let added = ShortcutStore.shared.add(name: name, url: url, colorHex: draft.colorHex)
            AppState.shared.showToast(added ? tr("تمت الإضافة للاختصارات", "Added to shortcuts")
                                            : tr("الموقع موجود مسبقاً", "Site already exists"))
        }
        dismiss()
    }
}

// MARK: - إدارة وترتيب الاختصارات

struct ManageShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ShortcutStore.shared
    @State private var editing: ShortcutDraft?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.shortcuts) { item in
                    Button { editing = ShortcutDraft(editing: item) } label: {
                        HStack(spacing: 12) {
                            ShortcutIcon(item: item, size: 40)
                            VStack(alignment: .leading) {
                                Text(item.name).foregroundStyle(.primary)
                                Text(item.url.host ?? item.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onMove { store.move(from: $0, to: $1) }
                .onDelete { offsets in offsets.map { store.shortcuts[$0].id }.forEach(store.remove) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(tr("ترتيب الاختصارات", "Arrange shortcuts"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("تم", "Done")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { editing = ShortcutDraft() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { ShortcutEditorSheet(draft: $0) }
        }
    }
}
