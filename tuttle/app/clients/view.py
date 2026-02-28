from typing import Callable, Mapping, Optional

from flet import (
    AlertDialog,
    Card,
    Column,
    Container,
    Icon,
    ListTile,
    ResponsiveRow,
    Row,
    Text,
    Control,
    Alignment,
    Border,
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


class ClientCard(Container):
    """Flat bordered card for a client entity."""

    def __init__(
        self,
        client: Client,
        on_edit: Optional[Callable] = None,
        on_delete: Optional[Callable] = None,
    ):
        self.client = client
        self.on_edit_clicked = on_edit
        self.on_delete_clicked = on_delete

        initials = _initials(client.name)
        avatar = Container(
            width=36,
            height=36,
            bgcolor=colors.accent_muted,
            border_radius=dimens.RADIUS_LG,
            alignment=Alignment.CENTER,
            content=Text(
                initials,
                size=fonts.BODY_1_SIZE,
                color=colors.accent,
                weight=fonts.BOLD_FONT,
            ),
        )

        editable = on_edit or on_delete
        trailing = (
            views.TContextMenu(
                on_click_delete=lambda e: self.on_delete_clicked(client),
                on_click_edit=lambda e: self.on_edit_clicked(client),
            )
            if editable
            else views.Spacer(sm_space=True)
        )

        if client.invoicing_contact:
            contact_info = client.invoicing_contact.print_address()
        else:
            contact_info = "Not specified"

        super().__init__(
            expand=True,
            bgcolor=colors.bg_surface,
            border=Border.all(dimens.CARD_BORDER_WIDTH, colors.border),
            border_radius=dimens.RADIUS_LG,
            padding=Padding.all(dimens.SPACE_MD),
            on_hover=self._on_hover,
            content=Column(
                spacing=dimens.SPACE_SM,
                controls=[
                    Row(
                        controls=[
                            Row(
                                controls=[
                                    avatar,
                                    views.TBodyText(
                                        client.name, weight=fonts.BOLD_FONT
                                    ),
                                ],
                                spacing=dimens.SPACE_SM,
                                vertical_alignment=utils.CENTER_ALIGNMENT,
                            ),
                            trailing,
                        ],
                        alignment=utils.SPACE_BETWEEN_ALIGNMENT,
                        vertical_alignment=utils.CENTER_ALIGNMENT,
                    ),
                    Container(height=1, bgcolor=colors.border_subtle),
                    views.TBodyText(
                        "Invoicing Contact",
                        color=colors.text_muted,
                        size=fonts.OVERLINE_SIZE,
                    ),
                    views.TBodyText(contact_info, size=fonts.BODY_2_SIZE),
                ],
            ),
        )

    def _on_hover(self, e):
        self.bgcolor = (
            colors.bg_surface_hovered if e.data == "true" else colors.bg_surface
        )
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
                    controls=[ClientCard(client=client)],
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


class ClientsListView(views.CrudListView):
    """View for displaying a list of clients"""

    entity_name = "client"
    entity_name_plural = "clients"
    on_add_intent_key = res_utils.ADD_CLIENT_INTENT

    def __init__(self, params: TViewParams):
        self.intent = ClientsIntent()
        super().__init__(params=params)
        self.contacts = {}
        self.editor = None

    def make_card(self, client):
        return ClientCard(
            client=client,
            on_edit=self.on_edit_client_clicked,
            on_delete=lambda c: self.on_delete_clicked(c),
        )

    def get_entity_description(self, client):
        return client.name

    def load_extra_data(self):
        self.contacts = self.intent.get_all_contacts_as_map()

    def open_add_editor(self, data=None):
        if self.editor:
            self.editor.close_dialog()
        self.editor = ClientEditorPopUp(
            self.dialog_controller,
            on_submit=self._on_save_client,
            contacts_map=self.contacts,
            on_error=lambda error: self.show_snack(error, is_error=True),
        )
        self.editor.open_dialog()

    def on_edit_client_clicked(self, client: Client):
        if self.editor:
            self.editor.close_dialog()
        self.editor = ClientEditorPopUp(
            self.dialog_controller,
            on_submit=self._on_save_client,
            contacts_map=self.contacts,
            client=client,
            on_error=lambda error: self.show_snack(error, is_error=True),
        )
        self.editor.open_dialog()

    def _on_save_client(self, client_to_save: Client):
        self.loading_indicator.visible = True
        self.update_self()
        result = self.intent.save_client(client_to_save)
        is_error = not result.was_intent_successful
        if not is_error:
            self.items_to_display[result.data.id] = result.data
            self.refresh_list()
        msg = result.error_msg if is_error else "Client saved!"
        self.show_snack(msg, is_error)
        self.loading_indicator.visible = False
        self.update_self()

    def will_unmount(self):
        super().will_unmount()
        if self.editor:
            self.editor.dimiss_open_dialogs()
