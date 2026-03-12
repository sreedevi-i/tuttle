from typing import Callable, Mapping, Optional

from flet import (
    AlertDialog,
    Card,
    ClipBehavior,
    Column,
    Container,
    Icon,
    Icons,
    ListTile,
    MainAxisAlignment,
    CrossAxisAlignment,
    ResponsiveRow,
    Row,
    Text,
    TextButton,
    Control,
    Alignment,
    Border,
    BorderSide,
    Padding,
)

from ..clients.intent import ClientsIntent
from ..core import utils, views
from ..core.abstractions import DialogHandler, TView, TViewParams
from ..core.intent_result import IntentResult
from ..res import colors, dimens, fonts, res_utils

from ...model import Address, Client, Contact


def _initials(name: str) -> str:
    parts = (name or "").split()
    return "".join(p[0].upper() for p in parts[:2]) if parts else "?"


class ClientRow(Container):
    """Single-line list row for a client — macOS native table style."""

    def __init__(
        self,
        client: Client,
        on_click=None,
        on_edit=None,
        on_delete=None,
        is_selected=False,
    ):
        self.client = client

        contact_name = (
            client.invoicing_contact.name if client.invoicing_contact else "—"
        )
        company = (
            client.invoicing_contact.company
            if client.invoicing_contact and client.invoicing_contact.company
            else "—"
        )

        _bg = colors.accent_muted if is_selected else colors.bg

        super().__init__(
            bgcolor=_bg,
            border=Border(bottom=BorderSide(1, colors.border)),
            padding=Padding.symmetric(
                horizontal=dimens.SPACE_MD, vertical=dimens.SPACE_SM
            ),
            on_click=lambda e: on_click(client) if on_click else None,
            on_hover=self._on_hover,
            clip_behavior=ClipBehavior.HARD_EDGE,
            content=Row(
                spacing=dimens.SPACE_MD,
                vertical_alignment=utils.CENTER_ALIGNMENT,
                controls=[
                    Container(
                        expand=True,
                        clip_behavior=ClipBehavior.HARD_EDGE,
                        content=Text(
                            client.name or "",
                            size=fonts.BODY_1_SIZE,
                            color=colors.text_primary,
                            weight=fonts.BOLD_FONT if is_selected else None,
                            overflow="ellipsis",
                            max_lines=1,
                        ),
                    ),
                    Container(
                        width=200,
                        clip_behavior=ClipBehavior.HARD_EDGE,
                        content=Text(
                            contact_name,
                            size=fonts.BODY_2_SIZE,
                            color=colors.text_secondary,
                            overflow="ellipsis",
                            max_lines=1,
                        ),
                    ),
                    Container(
                        width=200,
                        clip_behavior=ClipBehavior.HARD_EDGE,
                        content=Text(
                            company,
                            size=fonts.BODY_2_SIZE,
                            color=colors.text_muted,
                            overflow="ellipsis",
                            max_lines=1,
                        ),
                    ),
                ],
            ),
        )
        self._is_selected = is_selected

    def _on_hover(self, e):
        if self._is_selected:
            return
        self.bgcolor = colors.bg_surface_hovered if e.data == "true" else colors.bg
        self.update()


class ClientViewPopUp(DialogHandler, Column):
    """Pop up for viewing a client."""

    def __init__(
        self,
        dialog_controller: Callable[[any, utils.AlertDialogControls], None],
        client: Client,
    ):
        dialog = AlertDialog(
            bgcolor=colors.bg_surface,
            content=Container(
                content=Column(
                    scroll=utils.AUTO_SCROLL,
                    controls=[ClientRow(client=client)],
                ),
                width=480,
            ),
        )
        super().__init__(dialog=dialog, dialog_controller=dialog_controller)


class ClientEditorPopUp(DialogHandler, Column):
    """Pop up used for creating or updating a client"""

    def __init__(
        self,
        dialog_controller: Callable[[any, utils.AlertDialogControls], None],
        on_submit: Callable,
        on_error: Callable[[str], None],
        contacts_map: Mapping[int, Contact],
        client: Optional[Client] = None,
    ):
        # dimensions of the pop up and the elements inside
        # accounting for margins and paddings
        pop_up_height = dimens.MIN_WINDOW_HEIGHT
        pop_up_width = int(dimens.MIN_WINDOW_WIDTH * 0.8)
        half_of_pop_up_width = int(dimens.MIN_WINDOW_WIDTH * 0.35)

        self.client = client if client is not None else Client()
        self.invoicing_contact = (
            self.client.invoicing_contact
            if self.client.invoicing_contact is not None
            else Contact()
        )
        self.address = (
            self.invoicing_contact.address
            if self.invoicing_contact.address is not None
            else Address()
        )
        if not self.invoicing_contact.address:
            self.invoicing_contact.address = self.address
        self.contacts_as_map = contacts_map
        self.contact_options = self.get_contacts_as_list()

        title = "Edit Client" if client is not None else "New Client"

        initial_selected_contact = self.get_contact_dropdown_item(
            self.invoicing_contact.id
        )

        pop_up_height = 550
        pop_up_width = 480
        half_width = 220

        self.first_name_field = views.TTextField(
            label="First Name",
            hint=self.invoicing_contact.first_name,
            initial_value=self.invoicing_contact.first_name,
        )

        self.last_name_field = views.TTextField(
            label="Last Name",
            hint=self.invoicing_contact.last_name,
            initial_value=self.invoicing_contact.last_name,
        )
        self.company_field = views.TTextField(
            label="Company",
            hint=self.invoicing_contact.company,
            initial_value=self.invoicing_contact.company,
        )
        self.email_field = views.TTextField(
            label="Email",
            hint=self.invoicing_contact.email,
            initial_value=self.invoicing_contact.email,
        )

        self.street_field = views.TTextField(
            label="Street",
            hint=self.invoicing_contact.address.street,
            initial_value=self.invoicing_contact.address.street,
            width=half_width,
        )
        self.street_num_field = views.TTextField(
            label="Street No.",
            hint=self.invoicing_contact.address.number,
            initial_value=self.invoicing_contact.address.number,
            width=half_width,
        )
        self.postal_code_field = views.TTextField(
            label="Postal code",
            hint=self.invoicing_contact.address.postal_code,
            initial_value=self.invoicing_contact.address.postal_code,
            width=half_width,
        )
        self.city_field = views.TTextField(
            label="City",
            hint=self.invoicing_contact.address.city,
            initial_value=self.invoicing_contact.address.city,
            width=half_width,
        )
        self.country_field = views.TTextField(
            label="Country",
            hint=self.invoicing_contact.address.country,
            initial_value=self.invoicing_contact.address.country,
        )
        self.client_name_field = views.TTextField(
            label="Client's name",
            hint=self.client.name,
            initial_value=self.client.name,
        )

        self.contacts_dropdown = views.TDropDown(
            on_change=self.on_contact_selected,
            label="Select contact",
            items=self.contact_options,
            initial_value=initial_selected_contact,
        )
        self.form_error_field = views.TErrorText(txt="", show=False)

        dialog = AlertDialog(
            bgcolor=colors.bg_surface,
            content=Container(
                height=pop_up_height,
                content=Column(
                    scroll=utils.AUTO_SCROLL,
                    spacing=dimens.SPACE_SM,
                    controls=[
                        views.THeading(title=title, size=fonts.HEADLINE_4_SIZE),
                        self.form_error_field,
                        self.client_name_field,
                        views.SectionLabel("Invoicing Contact"),
                        self.contacts_dropdown,
                        self.first_name_field,
                        self.last_name_field,
                        self.company_field,
                        self.email_field,
                        views.SectionLabel("Address"),
                        Row(
                            vertical_alignment=utils.CENTER_ALIGNMENT,
                            controls=[self.street_field, self.street_num_field],
                        ),
                        Row(
                            vertical_alignment=utils.CENTER_ALIGNMENT,
                            controls=[
                                self.postal_code_field,
                                self.city_field,
                            ],
                        ),
                        self.country_field,
                    ],
                ),
                width=pop_up_width,
            ),
            actions=[
                views.TPrimaryButton(label="Save", on_click=self.on_submit_btn_clicked),
            ],
        )
        super().__init__(dialog=dialog, dialog_controller=dialog_controller)
        self.on_submit_callback = on_submit
        self.on_error_callback = on_error
        self.form_error = ""

    def get_contacts_as_list(self):
        """transforms a map of id-contact_name to a list for dropdown options"""
        contacts_list = []
        for key in self.contacts_as_map:
            item = self.get_contact_dropdown_item(key)
            if item:
                contacts_list.append(item)
        return contacts_list

    def get_contact_dropdown_item(self, contact_id):
        """appends an id to the contact name for dropdown options"""
        if contact_id is not None and contact_id in self.contacts_as_map:
            return f"{contact_id}. {self.contacts_as_map[contact_id].name}"
        return ""

    def on_contact_selected(self, e):
        # parse selected value to extract id
        selected = e.control.value
        id = ""
        for c in selected:
            if c == ".":
                break
            id = id + c
        if int(id) in self.contacts_as_map:
            self.invoicing_contact: Contact = self.contacts_as_map[int(id)]
            self.set_invoicing_contact_fields()

    def set_invoicing_contact_fields(self):
        self.first_name_field.value = self.invoicing_contact.first_name
        self.last_name_field.value = self.invoicing_contact.last_name
        self.company_field.value = self.invoicing_contact.company
        self.email_field.value = self.invoicing_contact.email
        self.street_field.value = self.invoicing_contact.address.street
        self.street_num_field.value = self.invoicing_contact.address.number
        self.postal_code_field.value = self.invoicing_contact.address.postal_code
        self.city_field.value = self.invoicing_contact.address.city
        self.country_field.value = self.invoicing_contact.address.country
        self.dialog.update()

    def toggle_form_error(self):
        """toggles the form error field visibility"""
        self.form_error_field.value = self.form_error
        self.form_error_field.visible = True if self.form_error else False
        self.dialog.update()

    def on_submit_btn_clicked(self, e):
        """validates the form and calls the on_submit callback"""
        self.form_error = ""
        self.toggle_form_error()

        # get values from fields
        client_name = self.client_name_field.value.strip()
        first_name = self.first_name_field.value.strip()
        last_name = self.last_name_field.value.strip()
        company = self.company_field.value.strip()
        email = self.email_field.value.strip()
        street = self.street_field.value.strip()
        street_num = self.street_num_field.value.strip()
        postal_code = self.postal_code_field.value.strip()
        city = self.city_field.value.strip()
        country = self.country_field.value.strip()

        # update where updated else keep old value
        self.client.name = client_name if client_name else self.client.name
        self.invoicing_contact.first_name = (
            first_name if first_name else self.invoicing_contact.first_name
        )
        self.invoicing_contact.last_name = (
            last_name if last_name else self.invoicing_contact.last_name
        )
        self.invoicing_contact.company = (
            company if company else self.invoicing_contact.company
        )
        self.invoicing_contact.email = email if email else self.invoicing_contact.email
        self.address.street = (
            street if street else self.invoicing_contact.address.street
        )

        self.address.number = (
            street_num if street_num else self.invoicing_contact.address.number
        )
        self.address.postal_code = (
            postal_code if postal_code else self.invoicing_contact.address.postal_code
        )
        self.address.city = city if city else self.invoicing_contact.address.city
        self.address.country = (
            country if country else self.invoicing_contact.address.country
        )
        self.invoicing_contact.address = self.address
        self.client.invoicing_contact = self.invoicing_contact
        if not self.is_valid():
            self.toggle_form_error()
            return
        self.close_dialog()
        self.on_submit_callback(self.client)

    def is_valid(self) -> bool:
        """Checks if the provided client info is valid"""
        if not self.client.name:
            self.form_error = "Please provide the client's name"
            self.on_error_callback(self.form_error)
            return False
        if not self.client.invoicing_contact:
            self.form_error = "Please set the invoicing contact"
            self.on_error_callback(self.form_error)
            return False
        if (
            not self.client.invoicing_contact.first_name
            or not self.client.invoicing_contact.last_name
        ):
            self.form_error = "Please provide the contact's name"
            self.on_error_callback(self.form_error)
            return False
        if self.client.invoicing_contact.address.is_empty:
            self.form_error = "Please provide the invoice contact's address"
            self.on_error_callback(self.form_error)
            return False
        return True

    def build(self):
        """Builds the dialog"""
        self.controls = [self.dialog]


# ── Side panel ────────────────────────────────────────────────


class ClientSidePanel(views.EntitySidePanel):
    """Right-side panel for viewing and editing clients."""

    def __init__(
        self,
        on_close,
        on_save,
        on_delete,
        intent: ClientsIntent,
        on_edit_requested=None,
    ):
        self.intent = intent
        self._contacts_map: dict = {}
        self._invoicing_contact: Optional[Contact] = None
        self._address: Optional[Address] = None
        super().__init__(
            on_close=on_close,
            on_save=on_save,
            on_delete=on_delete,
            on_edit_requested=on_edit_requested,
        )

    def _load_contacts(self):
        self._contacts_map = self.intent.get_all_contacts_as_map()

    def _contact_item(self, cid):
        return f"{cid}. {self._contacts_map[cid].name}"

    def _contact_options(self):
        return [self._contact_item(cid) for cid in self._contacts_map]

    # -- Detail view ----------------------------------------------------------

    def build_detail_content(self, entity: Client) -> list:
        c = entity
        contact = c.invoicing_contact
        controls = []

        # Client name as heading is already handled by panel title

        if contact:
            name = (
                f"{contact.first_name or ''} {contact.last_name or ''}".strip() or "—"
            )
            controls.append(
                self._get_detail_field("Contact Name", name, Icons.PERSON_OUTLINE)
            )
            if contact.company:
                controls.append(
                    self._get_detail_field("Company", contact.company, Icons.BUSINESS)
                )
            if contact.email:
                controls.append(
                    self._get_detail_field("Email", contact.email, Icons.EMAIL_OUTLINED)
                )
            controls.append(self._get_section_divider())

            addr = contact.address
            if addr and not addr.is_empty:
                street = f"{addr.street or ''} {addr.number or ''}".strip()
                city_line = f"{addr.postal_code or ''} {addr.city or ''}".strip()
                country = addr.country or ""
                addr_str = "\n".join(filter(None, [street, city_line, country]))
                controls.append(
                    self._get_detail_field(
                        "Address", addr_str, Icons.LOCATION_ON_OUTLINED
                    )
                )
            else:
                controls.append(
                    self._get_detail_field(
                        "Address", "Not specified", Icons.LOCATION_ON_OUTLINED
                    )
                )
        else:
            controls.append(self._get_detail_field("Contact", "Not specified"))

        controls.append(self._get_section_divider())

        # Actions
        controls.append(
            self._get_action_bar(
                views.TPrimaryButton(
                    label="Edit",
                    on_click=lambda e: self._switch_to_edit(),
                    icon=Icons.EDIT_OUTLINED,
                ),
                TextButton(
                    content=Text("Delete", color=colors.danger, size=fonts.BODY_2_SIZE),
                    on_click=lambda e: self._on_delete_cb(entity)
                    if self._on_delete_cb
                    else None,
                ),
            )
        )
        return controls

    def build_compact_detail(self, entity: Client) -> list:
        contact = entity.invoicing_contact
        email = "\u2014"
        addr_str = "\u2014"
        if contact:
            email = contact.email or "\u2014"
            addr = contact.address
            if addr and not addr.is_empty:
                street = f"{addr.street or ''} {addr.number or ''}".strip()
                city_line = f"{addr.postal_code or ''} {addr.city or ''}".strip()
                country = addr.country or ""
                addr_str = ", ".join(filter(None, [street, city_line, country]))

        return [
            ResponsiveRow(
                controls=[
                    self._compact_field("Email", email),
                    self._compact_field("Address", addr_str, col={"xs": 6}),
                ],
            ),
            self._get_action_bar(
                views.TPrimaryButton(
                    label="Edit",
                    on_click=lambda e: self._switch_to_edit(),
                    icon=Icons.EDIT_OUTLINED,
                ),
                TextButton(
                    content=Text("Delete", color=colors.danger, size=fonts.BODY_2_SIZE),
                    on_click=lambda e: self._on_delete_cb(entity)
                    if self._on_delete_cb
                    else None,
                ),
            ),
        ]

    # -- Edit view ------------------------------------------------------------

    def build_edit_content(self, entity: Optional[Client]) -> list:
        self._load_contacts()
        is_new = entity is None

        client = entity or Client()
        self._invoicing_contact = (
            client.invoicing_contact if client.invoicing_contact else Contact()
        )
        self._address = (
            self._invoicing_contact.address
            if self._invoicing_contact.address
            else Address()
        )
        if not self._invoicing_contact.address:
            self._invoicing_contact.address = self._address

        self._client_name_field = views.TTextField(
            label="Client Name",
            hint="Client's name",
            initial_value=client.name or "",
        )

        # Contact selector
        self._contacts_field = views.TDropDown(
            label="Existing contact",
            on_change=self._on_contact_selected,
            items=self._contact_options(),
        )
        if (
            self._invoicing_contact.id
            and self._invoicing_contact.id in self._contacts_map
        ):
            self._contacts_field.update_value(
                self._contact_item(self._invoicing_contact.id)
            )

        self._fname_field = views.TTextField(
            label="First Name",
            initial_value=self._invoicing_contact.first_name or "",
        )
        self._lname_field = views.TTextField(
            label="Last Name",
            initial_value=self._invoicing_contact.last_name or "",
        )
        self._company_field = views.TTextField(
            label="Company",
            initial_value=self._invoicing_contact.company or "",
        )
        self._email_field = views.TTextField(
            label="Email",
            initial_value=self._invoicing_contact.email or "",
        )
        self._street_field = views.TTextField(
            label="Street",
            initial_value=self._address.street or "",
        )
        self._street_num_field = views.TTextField(
            label="No.",
            initial_value=self._address.number or "",
        )
        self._postal_field = views.TTextField(
            label="Postal Code",
            initial_value=self._address.postal_code or "",
        )
        self._city_field = views.TTextField(
            label="City",
            initial_value=self._address.city or "",
        )
        self._country_field = views.TTextField(
            label="Country",
            initial_value=self._address.country or "",
        )

        save_label = "Create Client" if is_new else "Save Changes"

        # -- Multi-column layout --
        self._client_name_field.col = {"xs": 12, "sm": 6}
        self._contacts_field.col = {"xs": 12, "sm": 6}
        self._fname_field.col = {"xs": 6, "sm": 6}
        self._lname_field.col = {"xs": 6, "sm": 6}
        self._company_field.col = {"xs": 12, "sm": 6}
        self._email_field.col = {"xs": 12, "sm": 6}
        self._street_field.col = {"xs": 8, "sm": 8}
        self._street_num_field.col = {"xs": 4, "sm": 4}
        self._postal_field.col = {"xs": 4, "sm": 4}
        self._city_field.col = {"xs": 8, "sm": 4}
        self._country_field.col = {"xs": 12, "sm": 4}

        return [
            ResponsiveRow(
                controls=[self._client_name_field, self._contacts_field],
                spacing=dimens.SPACE_SM,
            ),
            views.SectionLabel("Contact"),
            ResponsiveRow(
                controls=[self._fname_field, self._lname_field],
                spacing=dimens.SPACE_SM,
            ),
            ResponsiveRow(
                controls=[self._company_field, self._email_field],
                spacing=dimens.SPACE_SM,
            ),
            views.SectionLabel("Address"),
            ResponsiveRow(
                controls=[self._street_field, self._street_num_field],
                spacing=dimens.SPACE_SM,
            ),
            ResponsiveRow(
                controls=[
                    self._postal_field,
                    self._city_field,
                    self._country_field,
                ],
                spacing=dimens.SPACE_SM,
            ),
            self._edit_action_bar(
                save_label,
                on_save=lambda e: self._validate_and_save(),
                on_cancel=lambda e: self.close(),
            ),
        ]

    def _on_contact_selected(self, e):
        sel = e.control.value
        cid = int(sel.split(".")[0])
        if cid in self._contacts_map:
            self._invoicing_contact = self._contacts_map[cid]
            self._address = self._invoicing_contact.address or Address()
            # Fill in the fields
            self._fname_field.value = self._invoicing_contact.first_name or ""
            self._lname_field.value = self._invoicing_contact.last_name or ""
            self._company_field.value = self._invoicing_contact.company or ""
            self._email_field.value = self._invoicing_contact.email or ""
            self._street_field.value = self._address.street or ""
            self._street_num_field.value = self._address.number or ""
            self._postal_field.value = self._address.postal_code or ""
            self._city_field.value = self._address.city or ""
            self._country_field.value = self._address.country or ""
            self.update()

    def _validate_and_save(self):
        client_name = (self._client_name_field.value or "").strip()
        if not client_name:
            self._client_name_field.error = "Client name is required"
            self.update()
            return

        fname = (self._fname_field.value or "").strip()
        lname = (self._lname_field.value or "").strip()
        if not fname or not lname:
            if not fname:
                self._fname_field.error = "Required"
            if not lname:
                self._lname_field.error = "Required"
            self.update()
            return

        # Update address
        self._address.street = (self._street_field.value or "").strip()
        self._address.number = (self._street_num_field.value or "").strip()
        self._address.postal_code = (self._postal_field.value or "").strip()
        self._address.city = (self._city_field.value or "").strip()
        self._address.country = (self._country_field.value or "").strip()

        if self._address.is_empty:
            return  # need at least some address

        # Update contact
        self._invoicing_contact.first_name = fname
        self._invoicing_contact.last_name = lname
        self._invoicing_contact.company = (self._company_field.value or "").strip()
        self._invoicing_contact.email = (self._email_field.value or "").strip()
        self._invoicing_contact.address = self._address

        # Update client
        client = self._entity or Client()
        client.name = client_name
        client.invoicing_contact = self._invoicing_contact

        if self._on_save_cb:
            self._on_save_cb(client)


class ClientsListView(views.CrudListView):
    """View for displaying a list of clients"""

    entity_name = "client"
    entity_name_plural = "clients"
    on_add_intent_key = res_utils.ADD_CLIENT_INTENT

    def get_sortable_fields(self):
        return [
            ("Name", lambda c: (c.name or "").lower()),
        ]

    def __init__(self, params: TViewParams):
        self.intent = ClientsIntent()
        super().__init__(params=params)

    def get_side_panel(self):
        return ClientSidePanel(
            on_close=self._on_panel_closed,
            on_save=self._on_save_client,
            on_delete=self.on_delete_clicked,
            intent=self.intent,
            on_edit_requested=self._on_inline_edit_requested,
        )

    def get_column_headers(self):
        return [
            ("Client", None),
            ("Contact", 200),
            ("Company", 200),
        ]

    def make_card(self, client):
        is_selected = self._selected_entity_id == (
            client.id if hasattr(client, "id") else None
        )
        return ClientRow(
            client=client,
            on_click=lambda c: self.open_detail_panel(c),
            on_edit=lambda c: self.open_edit_panel(c),
            on_delete=lambda c: self.on_delete_clicked(c),
            is_selected=is_selected,
        )

    def get_entity_description(self, client):
        return client.name

    def load_extra_data(self):
        pass  # contacts loaded by panel on demand

    def parent_intent_listener(self, intent: str, data=None):
        if intent == res_utils.RELOAD_INTENT:
            self.reload_all_data()
        elif intent == res_utils.ADD_CLIENT_INTENT:
            self.open_edit_panel(None)

    def open_add_editor(self, data=None):
        self.open_edit_panel(None)

    def _on_save_client(self, client_to_save: Client):
        result = self.intent.save_client(client_to_save)
        if result.was_intent_successful:
            self.show_snack("Client saved!")
            self._side_panel.close()
            self.reload_all_data()
        else:
            self.show_snack(result.error_msg, is_error=True)
