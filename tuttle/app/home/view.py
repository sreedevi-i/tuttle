from typing import Callable, Optional

import webbrowser
from dataclasses import dataclass

from flet import (
    Alignment,
    Border,
    BorderSide,
    Column,
    Container,
    ElevatedButton,
    Icon,
    IconButton,
    Icons,
    Margin,
    NavigationRailDestination,
    Padding,
    PopupMenuButton,
    PopupMenuItem,
    ResponsiveRow,
    Row,
    Text,
    Control,
    ScrollMode,
    MainAxisAlignment,
    CrossAxisAlignment,
    TextStyle,
)

from ..clients.view import ClientsListView
from ..contacts.view import ContactsListView
from ..contracts.view import ContractsListView
from ..core import utils, views
from ..core.abstractions import DialogHandler, TView, TViewParams
from ..invoicing.view import InvoicingListView
from ..projects.view import ProjectsListView
from ..res import colors, dimens, fonts, res_utils, theme
from ..timetracking.view import TimeTrackingView

from ..preferences.intent import PreferencesIntent


def get_toolbar(
    title: str,
    on_click_new_btn: Callable,
    on_click_profile_btn: Callable,
    on_view_settings_clicked: Callable,
):
    """Compact toolbar — title on the left, actions on the right."""
    return Container(
        alignment=Alignment.CENTER,
        height=dimens.TOOLBAR_HEIGHT,
        bgcolor=colors.bg_toolbar,
        padding=Padding.symmetric(horizontal=dimens.SPACE_MD),
        border=Border.only(
            bottom=BorderSide(width=1, color=colors.border_subtle),
        ),
        content=Row(
            alignment=utils.SPACE_BETWEEN_ALIGNMENT,
            vertical_alignment=CrossAxisAlignment.CENTER,
            controls=[
                Row(
                    controls=[
                        views.THeading(title, size=fonts.HEADLINE_4_SIZE),
                    ],
                    vertical_alignment=CrossAxisAlignment.CENTER,
                ),
                Row(
                    spacing=dimens.SPACE_XS,
                    controls=[
                        ElevatedButton(
                            content="New",
                            icon=Icons.ADD,
                            icon_color=colors.accent,
                            color=colors.accent,
                            bgcolor=colors.bg_surface,
                            height=dimens.CLICKABLE_STD_HEIGHT,
                            on_click=on_click_new_btn,
                            style=views.ButtonStyle(
                                shape=views.RoundedRectangleBorder(
                                    radius=dimens.RADIUS_MD
                                ),
                                side=BorderSide(width=1, color=colors.border),
                                elevation=0,
                            ),
                        ),
                        IconButton(
                            icon=Icons.SETTINGS_OUTLINED,
                            icon_size=dimens.ICON_SIZE,
                            icon_color=colors.text_secondary,
                            on_click=on_view_settings_clicked,
                            tooltip="Preferences",
                        ),
                        IconButton(
                            icon=Icons.PERSON_OUTLINE_OUTLINED,
                            icon_size=dimens.ICON_SIZE,
                            icon_color=colors.text_secondary,
                            tooltip="Profile",
                            on_click=on_click_profile_btn,
                        ),
                        PopupMenuButton(
                            icon=Icons.HELP_OUTLINE,
                            icon_size=dimens.ICON_SIZE,
                            icon_color=colors.text_secondary,
                            items=[
                                PopupMenuItem(
                                    icon=Icons.CONTACT_SUPPORT,
                                    content="Ask a question",
                                    on_click=lambda _: webbrowser.open(
                                        "https://github.com/tuttle-dev/tuttle/discussions"
                                    ),
                                ),
                                PopupMenuItem(
                                    icon=Icons.BUG_REPORT,
                                    content="Report a bug",
                                    on_click=lambda _: webbrowser.open(
                                        "https://github.com/tuttle-dev/tuttle/issues"
                                    ),
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    )


class MainMenuItemsHandler:
    """Manages home's main-menu items."""

    def __init__(self, params: TViewParams):
        super().__init__()
        self.menu_title = "My Business"
        self.projects_view = ProjectsListView(params)
        self.contacts_view = ContactsListView(params)
        self.clients_view = ClientsListView(params)
        self.contracts_view = ContractsListView(params)
        self.items = [
            views.NavigationMenuItem(
                index=0,
                label="Projects",
                icon=utils.TuttleComponentIcons.project_icon,
                selected_icon=utils.TuttleComponentIcons.project_selected_icon,
                destination=self.projects_view,
                on_new_screen_route=res_utils.PROJECT_EDITOR_SCREEN_ROUTE,
            ),
            views.NavigationMenuItem(
                index=1,
                label="Contracts",
                icon=utils.TuttleComponentIcons.contract_icon,
                selected_icon=utils.TuttleComponentIcons.contract_selected_icon,
                destination=self.contracts_view,
                on_new_screen_route=res_utils.CONTRACT_EDITOR_SCREEN_ROUTE,
            ),
            views.NavigationMenuItem(
                index=2,
                label="Clients",
                icon=utils.TuttleComponentIcons.client_icon,
                selected_icon=utils.TuttleComponentIcons.client_selected_icon,
                destination=self.clients_view,
                on_new_intent=res_utils.ADD_CLIENT_INTENT,
            ),
            views.NavigationMenuItem(
                index=3,
                label="Contacts",
                icon=utils.TuttleComponentIcons.contact_icon,
                selected_icon=utils.TuttleComponentIcons.contact_selected_icon,
                destination=self.contacts_view,
                on_new_intent=res_utils.ADD_CONTACT_INTENT,
            ),
        ]


class SecondaryMenuHandler:
    """Manages home's workflow-menu items."""

    def __init__(self, params: TViewParams):
        super().__init__()
        self.menu_title = "Workflows"
        self.timetrack_view = TimeTrackingView(params)
        self.invoicing_view = InvoicingListView(params)
        self.items = [
            views.NavigationMenuItem(
                index=0,
                label="Time Tracking",
                icon=utils.TuttleComponentIcons.timetracking_icon,
                selected_icon=utils.TuttleComponentIcons.timetracking_selected_icon,
                destination=self.timetrack_view,
                on_new_intent=res_utils.NEW_TIME_TRACK_INTENT,
            ),
            views.NavigationMenuItem(
                index=1,
                label="Invoicing",
                icon=utils.TuttleComponentIcons.invoicing_icon,
                selected_icon=utils.TuttleComponentIcons.invoicing_selected_icon,
                destination=self.invoicing_view,
                on_new_intent=res_utils.CREATE_INVOICE_INTENT,
            ),
        ]


class HomeScreen(TView, Container):
    """Main app shell — sidebar + toolbar + content area + status bar."""

    def __init__(self, params: TViewParams):
        super().__init__(params)
        self.keep_back_stack = False
        self.page_scroll_type = None
        self.main_menu_handler = MainMenuItemsHandler(params)
        self.secondary_menu_handler = SecondaryMenuHandler(params)
        self.preferences_intent = PreferencesIntent(
            client_storage=params.client_storage
        )

        # Build flat list of all items for the sidebar
        self._all_items: list[views.NavigationMenuItem] = list(
            self.main_menu_handler.items
        ) + list(self.secondary_menu_handler.items)
        self._selected_flat_index = 0

        # Create sidebar panel
        self.sidebar_panel = views.SidebarPanel(
            sections=[
                (self.main_menu_handler.menu_title, self.main_menu_handler.items),
                (
                    self.secondary_menu_handler.menu_title,
                    self.secondary_menu_handler.items,
                ),
            ],
            on_item_selected=self._on_sidebar_item_selected,
            initial_selected_index=0,
        )

        self.destination_view = self._all_items[0].destination
        self.dialog: Optional[DialogHandler] = None

        # Toolbar (title updates on nav change)
        self._toolbar_title = self._all_items[0].label
        self.toolbar = get_toolbar(
            title=self._toolbar_title,
            on_click_new_btn=self.on_click_add_new,
            on_click_profile_btn=self.on_click_profile,
            on_view_settings_clicked=self.on_view_settings_clicked,
        )

    def _on_sidebar_item_selected(self, item: views.NavigationMenuItem):
        """Called when the user clicks a sidebar nav item."""
        self._selected_flat_index = self._all_items.index(item)
        self.destination_view = item.destination
        self.destination_content_container.content = self.destination_view
        # Update toolbar title
        self._toolbar_title = item.label
        self.toolbar = get_toolbar(
            title=self._toolbar_title,
            on_click_new_btn=self.on_click_add_new,
            on_click_profile_btn=self.on_click_profile,
            on_view_settings_clicked=self.on_view_settings_clicked,
        )
        self.main_body.controls = [self.toolbar, self.destination_content_container]
        self.update_self()

    # ── Action buttons ────────────────────────────────────────
    def on_click_add_new(self, e):
        item = self._all_items[self._selected_flat_index]
        if item.on_new_intent:
            self.pass_intent_to_destination(item.on_new_intent)
        elif item.on_new_screen_route:
            self.navigate_to_route(item.on_new_screen_route)

    def on_resume_after_back_pressed(self):
        if self.destination_view and isinstance(self.destination_view, TView):
            self.destination_view.on_resume_after_back_pressed()

    def pass_intent_to_destination(self, intent: str, data=None):
        if self.destination_view and isinstance(self.destination_view, TView):
            self.destination_view.parent_intent_listener(intent, data)

    def on_view_notifications_clicked(self, e):
        self.show_snack("not implemented", True)

    def on_view_settings_clicked(self, e):
        self.navigate_to_route(res_utils.PREFERENCES_SCREEN_ROUTE)

    def on_click_profile(self, e):
        self.navigate_to_route(res_utils.PROFILE_SCREEN_ROUTE)

    # ── Build ─────────────────────────────────────────────────
    def build(self):
        self.destination_content_container = Container(
            padding=Padding.all(dimens.SPACE_MD),
            content=self.destination_view,
            expand=True,
        )

        # Status bar — VS Code style thin bar at bottom
        self.status_bar = Container(
            height=dimens.FOOTER_HEIGHT,
            bgcolor=colors.bg_statusbar,
            padding=Padding.symmetric(horizontal=dimens.SPACE_SM),
            content=Row(
                controls=[
                    Text("Tuttle", size=11, color=colors.text_inverse),
                ],
                alignment=MainAxisAlignment.START,
                vertical_alignment=CrossAxisAlignment.CENTER,
            ),
        )

        # Sidebar
        self.side_bar = Container(
            width=dimens.SIDEBAR_WIDTH,
            bgcolor=colors.bg_sidebar,
            padding=Padding.only(top=dimens.SPACE_LG),
            content=Column(
                controls=[self.sidebar_panel],
                alignment=MainAxisAlignment.START,
                spacing=0,
                expand=True,
            ),
            border=Border.only(
                right=BorderSide(width=1, color=colors.border_subtle),
            ),
        )

        # Main body
        self.main_body = Column(
            expand=True,
            alignment=MainAxisAlignment.START,
            horizontal_alignment=CrossAxisAlignment.START,
            spacing=0,
            controls=[
                self.toolbar,
                self.destination_content_container,
            ],
        )

        self.home_screen_view = Container(
            bgcolor=colors.bg,
            expand=True,
            content=Column(
                controls=[
                    Row(
                        controls=[self.side_bar, self.main_body],
                        spacing=0,
                        alignment=MainAxisAlignment.START,
                        vertical_alignment=CrossAxisAlignment.START,
                        expand=True,
                    ),
                    self.status_bar,
                ],
                alignment=MainAxisAlignment.SPACE_BETWEEN,
                horizontal_alignment=CrossAxisAlignment.STRETCH,
                spacing=0,
            ),
        )
        self.content = self.home_screen_view
        self.expand = True

    def did_mount(self):
        self.mounted = True

    def on_resume_after_back_pressed(self):
        self.pass_intent_to_destination(res_utils.RELOAD_INTENT)

    def on_window_resized_listener(self, width, height):
        if not self.mounted:
            return
        super().on_window_resized_listener(width, height)
        self.update_self()

    def will_unmount(self):
        self.mounted = False
        if self.dialog:
            self.dialog.dimiss_open_dialogs()
