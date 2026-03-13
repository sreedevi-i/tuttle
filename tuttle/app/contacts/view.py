from typing import Callable, Optional

from flet import (
    AlertDialog,
    Card,
    ClipBehavior,
    Column,
    Container,
    Icon,
    IconButton,
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


class ContactRow(Container):
    """Single-line list row for a contact — macOS native table style."""

    def __init__(
        self,
        contact: Contact,
        on_click,
        on_edit_clicked,
        on_deleted_clicked,
        is_selected=False,
    ):
        self.contact = contact

        company = contact.company or "—"
        email = contact.email or "—"

        _bg = colors.accent_muted if is_selected else colors.bg

        super().__init__(
            bgcolor=_bg,
            border=Border(bottom=BorderSide(1, colors.border_subtle)),
            padding=Padding.symmetric(
                horizontal=dimens.SPACE_MD, vertical=dimens.SPACE_STD
            ),
            on_click=lambda e: on_click(contact),
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
                            contact.name or "",
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
                            company,
                            size=fonts.BODY_2_SIZE,
                            color=colors.text_secondary,
                            overflow="ellipsis",
                            max_lines=1,
                        ),
                    ),
                    Container(
                        width=220,
                        clip_behavior=ClipBehavior.HARD_EDGE,
                        content=Text(
                            email,
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


# ── Side panel ────────────────────────────────────────────────


class ContactSidePanel(views.EntitySidePanel):
    """Right-side panel for viewing and editing contacts."""

    def __init__(
        self,
        on_close,
        on_save,
        on_delete,
        intent: ContactsIntent,
        on_edit_requested=None,
    ):
        self.intent = intent
        super().__init__(
            on_close=on_close,
            on_save=on_save,
            on_delete=on_delete,
            on_edit_requested=on_edit_requested,
        )

    # -- Detail view ----------------------------------------------------------

    def build_detail_content(self, entity: Contact) -> list:
        c = entity
        controls = []

        name = f"{c.first_name or ''} {c.last_name or ''}".strip() or "—"
        controls.append(self._get_detail_field("Name", name, Icons.PERSON_OUTLINE))
        if c.company:
            controls.append(
                self._get_detail_field("Company", c.company, Icons.BUSINESS)
            )
        if c.email:
            controls.append(
                self._get_detail_field("Email", c.email, Icons.EMAIL_OUTLINED)
            )
        controls.append(self._get_section_divider())

        addr = c.address
        if addr and not addr.is_empty:
            street = f"{addr.street or ''} {addr.number or ''}".strip()
            city_line = f"{addr.postal_code or ''} {addr.city or ''}".strip()
            country = addr.country or ""
            addr_str = "\n".join(filter(None, [street, city_line, country]))
            controls.append(
                self._get_detail_field("Address", addr_str, Icons.LOCATION_ON_OUTLINED)
            )
        else:
            controls.append(
                self._get_detail_field(
                    "Address", "Not specified", Icons.LOCATION_ON_OUTLINED
                )
            )

        controls.append(self._get_section_divider())

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

    def build_compact_detail(self, entity: Contact) -> list:
        c = entity
        addr_str = "\u2014"
        addr = c.address
        if addr and not addr.is_empty:
            street = f"{addr.street or ''} {addr.number or ''}".strip()
            city_line = f"{addr.postal_code or ''} {addr.city or ''}".strip()
            country = addr.country or ""
            addr_str = ", ".join(filter(None, [street, city_line, country]))

        return [
            ResponsiveRow(
                controls=[
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

    def build_edit_content(self, entity: Optional[Contact]) -> list:
        is_new = entity is None
        contact = entity or Contact()
        if not contact.address:
            contact.address = Address()

        self._fname_field = views.TTextField(
            label="First Name",
            initial_value=contact.first_name or "",
        )
        self._lname_field = views.TTextField(
            label="Last Name",
            initial_value=contact.last_name or "",
        )
        self._company_field = views.TTextField(
            label="Company",
            initial_value=contact.company or "",
        )
        self._email_field = views.TTextField(
            label="Email",
            initial_value=contact.email or "",
        )
        self._street_field = views.TTextField(
            label="Street",
            initial_value=contact.address.street or "",
        )
        self._street_num_field = views.TTextField(
            label="No.",
            initial_value=contact.address.number or "",
        )
        self._postal_field = views.TTextField(
            label="Postal Code",
            initial_value=contact.address.postal_code or "",
        )
        self._city_field = views.TTextField(
            label="City",
            initial_value=contact.address.city or "",
        )
        self._country_field = views.TTextField(
            label="Country",
            initial_value=contact.address.country or "",
        )

        save_label = "Create Contact" if is_new else "Save Changes"

        # -- Multi-column layout --
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

    def _validate_and_save(self):
        fname = (self._fname_field.value or "").strip()
        lname = (self._lname_field.value or "").strip()
        if not fname:
            self._fname_field.error = "Required"
            self.update()
            return
        if not lname:
            self._lname_field.error = "Required"
            self.update()
            return

        contact = self._entity or Contact()
        if not contact.address:
            contact.address = Address()
        contact.first_name = fname
        contact.last_name = lname
        contact.company = (self._company_field.value or "").strip()
        contact.email = (self._email_field.value or "").strip()
        contact.address.street = (self._street_field.value or "").strip()
        contact.address.number = (self._street_num_field.value or "").strip()
        contact.address.postal_code = (self._postal_field.value or "").strip()
        contact.address.city = (self._city_field.value or "").strip()
        contact.address.country = (self._country_field.value or "").strip()

        if contact.address.is_empty:
            return  # need some address info

        if self._on_save_cb:
            self._on_save_cb(contact)


class ContactsListView(views.CrudListView):
    """The view for the contacts list page"""

    entity_name = "contact"
    entity_name_plural = "contacts"
    on_add_intent_key = res_utils.ADD_CONTACT_INTENT

    def get_sortable_fields(self):
        return [
            ("Last Name", lambda c: (c.last_name or "").lower()),
            ("First Name", lambda c: (c.first_name or "").lower()),
            ("Company", lambda c: (c.company or "").lower()),
        ]

    def __init__(self, params: TViewParams):
        self.intent = ContactsIntent()
        super().__init__(params)

    def get_toolbar_items(self):
        return [
            IconButton(
                icon=Icons.PERSON_ADD_ALT_1,
                tooltip="Add Contact",
                icon_color=colors.text_secondary,
                icon_size=dimens.ICON_SIZE,
                on_click=lambda e: self.open_edit_panel(None),
            ),
        ]

    def get_side_panel(self):
        return ContactSidePanel(
            on_close=self._on_panel_closed,
            on_save=self._on_save_contact,
            on_delete=self.on_delete_clicked,
            intent=self.intent,
            on_edit_requested=self._on_inline_edit_requested,
        )

    def get_column_headers(self):
        return [
            ("Name", None, 0),
            ("Company", 200, 2),
            ("Email", 220, None),
        ]

    def get_search_text(self, contact):
        return " ".join(
            filter(
                None,
                [contact.first_name, contact.last_name, contact.company, contact.email],
            )
        )

    def make_card(self, contact):
        is_selected = self._selected_entity_id == (
            contact.id if hasattr(contact, "id") else None
        )
        return ContactRow(
            contact=contact,
            on_click=lambda c: self.open_detail_panel(c),
            on_edit_clicked=lambda c: self.open_edit_panel(c),
            on_deleted_clicked=lambda c: self.on_delete_clicked(c),
            is_selected=is_selected,
        )

    def get_entity_description(self, contact):
        return f"{contact.first_name} {contact.last_name}"

    def open_add_editor(self, data=None):
        self.open_edit_panel(None)

    def parent_intent_listener(self, intent: str, data=None):
        if intent == res_utils.RELOAD_INTENT:
            self.reload_all_data()
        elif intent == res_utils.ADD_CONTACT_INTENT:
            self.open_edit_panel(None)

    def _on_save_contact(self, contact):
        result = self.intent.save_contact(contact)
        if result.was_intent_successful:
            self.show_snack("Contact saved!")
            self._side_panel.close()
            self.reload_all_data()
        else:
            self.show_snack(result.error_msg, is_error=True)

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
