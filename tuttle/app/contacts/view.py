from typing import Callable, Optional

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

from ..contacts.intent import ContactsIntent
from ..core import utils, views
from ..core.abstractions import DialogHandler, TView, TViewParams
from ..core.intent_result import IntentResult
from ..res import colors, dimens, fonts, res_utils

from ...model import Address, Contact


def _initials(name: str) -> str:
    """Extract up to 2 initials from a name."""
    parts = (name or "").split()
    return "".join(p[0].upper() for p in parts[:2]) if parts else "?"


class ContactCard(Container):
    """Flat, bordered card for a contact — VS Code panel style."""

    def __init__(self, contact: Contact, on_edit_clicked, on_deleted_clicked):
        self.contact = contact
        self.on_edit_clicked = on_edit_clicked
        self.on_deleted_clicked = on_deleted_clicked

        initials = _initials(contact.name)
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

        header = Row(
            controls=[
                avatar,
                Column(
                    spacing=0,
                    controls=[
                        views.TBodyText(
                            utils.truncate_str(contact.name, 30), weight=fonts.BOLD_FONT
                        ),
                        views.TBodyText(
                            utils.truncate_str(contact.company, 30),
                            color=colors.text_secondary,
                            size=fonts.BODY_2_SIZE,
                        ),
                    ],
                ),
            ],
            spacing=dimens.SPACE_SM,
            expand=True,
            vertical_alignment=utils.CENTER_ALIGNMENT,
        )

        context_menu = views.TContextMenu(
            on_click_edit=lambda e: self.on_edit_clicked(contact),
            on_click_delete=lambda e: self.on_deleted_clicked(contact),
        )

        body_items = []
        if contact.email:
            body_items.extend(
                [
                    views.TBodyText(
                        "Email", color=colors.text_muted, size=fonts.OVERLINE_SIZE
                    ),
                    views.TBodyText(contact.email, size=fonts.BODY_2_SIZE),
                    views.Spacer(sm_space=True),
                ]
            )
        address_str = (
            contact.print_address(address_only=True).strip() if contact.address else ""
        )
        if address_str:
            body_items.extend(
                [
                    views.TBodyText(
                        "Address", color=colors.text_muted, size=fonts.OVERLINE_SIZE
                    ),
                    views.TBodyText(address_str, size=fonts.BODY_2_SIZE),
                ]
            )

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
                        controls=[header, context_menu],
                        alignment=utils.SPACE_BETWEEN_ALIGNMENT,
                        vertical_alignment=utils.START_ALIGNMENT,
                    ),
                    Container(height=1, bgcolor=colors.border_subtle),
                    *body_items,
                ],
            ),
        )

    def _on_hover(self, e):
        self.bgcolor = (
            colors.bg_surface_hovered if e.data == "true" else colors.bg_surface
        )
        self.update()


class ContactEditorPopUp(DialogHandler):
    """Dialog for creating or editing a contact."""

    def __init__(
        self,
        dialog_controller: Callable[[any, utils.AlertDialogControls], None],
        on_submit: Callable,
        on_error: Callable,
        contact: Optional[Contact] = None,
    ):
        pop_up_height = 550
        pop_up_width = 480
        half_width = 220
        self.contact = contact
        if not self.contact:
            self.contact = Contact()
            self.contact.address = Address()
        self.address = self.contact.address

        title = "Edit Contact" if contact is not None else "New Contact"

        self.fname_field = views.TTextField(
            label="First Name",
            hint=self.contact.first_name,
            initial_value=self.contact.first_name,
        )
        self.lname_field = views.TTextField(
            label="Last Name",
            hint=self.contact.last_name,
            initial_value=self.contact.last_name,
        )
        self.company_name_field = views.TTextField(
            label="Company",
            hint=self.contact.company,
            initial_value=self.contact.company,
        )
        self.email_field = views.TTextField(
            label="Email", hint=self.contact.email, initial_value=self.contact.email
        )
        self.street_name_field = views.TTextField(
            label="Street",
            hint=self.contact.address.street,
            initial_value=self.contact.address.street,
            width=half_width,
        )
        self.street_num_field = views.TTextField(
            label="Street No.",
            hint=self.contact.address.number,
            initial_value=self.contact.address.number,
            width=half_width,
        )
        self.postal_code_field = views.TTextField(
            label="Postal code",
            hint=self.contact.address.postal_code,
            initial_value=self.contact.address.postal_code,
            width=half_width,
        )
        self.city_field = views.TTextField(
            label="City",
            hint=self.contact.address.city,
            initial_value=self.contact.address.city,
            width=half_width,
        )
        self.country_field = views.TTextField(
            label="Country",
            hint=self.contact.address.country,
            initial_value=self.contact.address.country,
        )

        dialog = AlertDialog(
            bgcolor=colors.bg_surface,
            content=Container(
                height=pop_up_height,
                content=Column(
                    scroll=utils.AUTO_SCROLL,
                    spacing=dimens.SPACE_SM,
                    controls=[
                        views.THeading(title=title, size=fonts.HEADLINE_4_SIZE),
                        views.Spacer(xs_space=True),
                        self.fname_field,
                        self.lname_field,
                        self.company_name_field,
                        self.email_field,
                        views.SectionLabel("Address"),
                        Row(
                            vertical_alignment=utils.CENTER_ALIGNMENT,
                            controls=[self.street_name_field, self.street_num_field],
                        ),
                        Row(
                            vertical_alignment=utils.CENTER_ALIGNMENT,
                            controls=[self.postal_code_field, self.city_field],
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

    def on_submit_btn_clicked(self, e):
        """Called when the submit button is clicked"""
        # get the values from the fields
        fname = self.fname_field.value.strip()
        lname = self.lname_field.value.strip()
        company = self.company_name_field.value.strip()
        email = self.email_field.value.strip()
        street = self.street_name_field.value.strip()
        street_num = self.street_num_field.value.strip()
        postal_code = self.postal_code_field.value.strip()
        city = self.city_field.value.strip()
        country = self.country_field.value.strip()

        # update where updated else keep old value
        self.contact.first_name = fname if fname else self.contact.first_name
        self.contact.last_name = lname if lname else self.contact.last_name
        self.contact.company = company if company else self.contact.company
        self.contact.email = email if email else self.contact.email
        self.address.street = street if street else self.contact.address.street

        self.address.number = street_num if street_num else self.contact.address.number
        self.address.postal_code = (
            postal_code if postal_code else self.contact.address.postal_code
        )
        self.address.city = city if city else self.contact.address.city
        self.address.country = country if country else self.contact.address.country
        self.contact.address = self.address
        if self.contact.address.is_empty:
            self.on_error_callback("Address cannot be empty")
            return
        if not self.contact.first_name or not self.contact.last_name:
            self.on_error_callback("First and last name cannot be empty")
            return
        self.close_dialog()
        self.on_submit_callback(self.contact)


class ContactsListView(views.CrudListView):
    """The view for the contacts list page"""

    entity_name = "contact"
    entity_name_plural = "contacts"
    on_add_intent_key = res_utils.ADD_CONTACT_INTENT

    def __init__(self, params: TViewParams):
        self.intent = ContactsIntent()
        super().__init__(params)
        self.editor = None

    def make_card(self, contact):
        return ContactCard(
            contact=contact,
            on_edit_clicked=self.on_edit_contact_clicked,
            on_deleted_clicked=lambda c: self.on_delete_clicked(c),
        )

    def get_entity_description(self, contact):
        return f"{contact.first_name} {contact.last_name}"

    def open_add_editor(self, data=None):
        if self.editor:
            self.editor.close_dialog()
        self.editor = ContactEditorPopUp(
            dialog_controller=self.dialog_controller,
            on_submit=self._on_save_contact,
            on_error=lambda error: self.show_snack(error, is_error=True),
        )
        self.editor.open_dialog()

    def on_edit_contact_clicked(self, contact: Contact):
        if self.editor:
            self.editor.close_dialog()
        self.editor = ContactEditorPopUp(
            dialog_controller=self.dialog_controller,
            contact=contact,
            on_submit=self._on_save_contact,
            on_error=lambda error: self.show_snack(error, is_error=True),
        )
        self.editor.open_dialog()

    def _on_save_contact(self, contact):
        self.loading_indicator.visible = True
        self.update_self()
        result = self.intent.save_contact(contact)
        is_error = not result.was_intent_successful
        if not is_error:
            saved = result.data
            self.items_to_display[saved.id] = saved
            self.refresh_list()
        msg = result.error_msg if is_error else "Contact saved!"
        self.show_snack(msg, is_error)
        self.loading_indicator.visible = False
        self.update_self()

    def on_delete_confirmed(self, contact_id):
        """Uses delete_contact for referential integrity check."""
        self.loading_indicator.visible = True
        self.update_self()
        result = self.intent.delete_contact(contact_id)
        is_error = not result.was_intent_successful
        msg = "Contact deleted!" if not is_error else result.error_msg
        self.show_snack(msg, is_error)
        if not is_error and contact_id in self.items_to_display:
            del self.items_to_display[contact_id]
        self.refresh_list()
        self.loading_indicator.visible = False
        self.update_self()

    def will_unmount(self):
        super().will_unmount()
        if self.editor:
            self.editor.dimiss_open_dialogs()
