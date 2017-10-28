<%@ Page language="C#"   Inherits="Microsoft.SharePoint.Publishing.PublishingLayoutPage,Microsoft.SharePoint.Publishing,Version=16.0.0.0,Culture=neutral,PublicKeyToken=71e9bce111e9429c" %>
<%@ Register Tagprefix="SharePointWebControls" Namespace="Microsoft.SharePoint.WebControls" Assembly="Microsoft.SharePoint, Version=16.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c" %> <%@ Register Tagprefix="WebPartPages" Namespace="Microsoft.SharePoint.WebPartPages" Assembly="Microsoft.SharePoint, Version=16.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c" %> <%@ Register Tagprefix="PublishingWebControls" Namespace="Microsoft.SharePoint.Publishing.WebControls" Assembly="Microsoft.SharePoint.Publishing, Version=16.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c" %> <%@ Register Tagprefix="PublishingNavigation" Namespace="Microsoft.SharePoint.Publishing.Navigation" Assembly="Microsoft.SharePoint.Publishing, Version=16.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c" %>
<asp:Content ContentPlaceholderID="PlaceHolderAdditionalPageHead" runat="server">
	<SharePointWebControls:CssRegistration name="<% $SPUrl:~sitecollection/Style Library/~language/Themable/Core Styles/pagelayouts15.css %>" runat="server"/>
	<PublishingWebControls:EditModePanel runat="server">
		<!-- Styles for edit mode only-->
		<SharePointWebControls:CssRegistration name="<% $SPUrl:~sitecollection/Style Library/~language/Themable/Core Styles/editmode15.css %>"
			After="<% $SPUrl:~sitecollection/Style Library/~language/Themable/Core Styles/pagelayouts15.css %>" runat="server"/>
	</PublishingWebControls:EditModePanel>
	<SharePointWebControls:CssRegistration name="<% $SPUrl:~sitecollection/Style Library/demo/css/home-page.css %>"
		After="<% $SPUrl:~sitecollection/Style Library/demo/css/styles.css %>" runat="server"/>	
</asp:Content>
<asp:Content ContentPlaceHolderId="PlaceHolderPageTitle" runat="server">
	<SharePointWebControls:ListProperty Property="Title" runat="server"/> - <SharePointWebControls:FieldValue FieldName="Title" runat="server"/>
</asp:Content>
<asp:Content ContentPlaceHolderId="PlaceHolderPageTitleInTitleArea" runat="server">
	<SharePointWebControls:FieldValue FieldName="Title" runat="server" />
</asp:Content>
<asp:Content ContentPlaceHolderId="PlaceHolderTitleBreadcrumb" runat="server"> <SharePointWebControls:ListSiteMapPath runat="server" SiteMapProviders="CurrentNavigationSwitchableProvider" RenderCurrentNodeAsLink="false" PathSeparator="" CssClass="s4-breadcrumb" NodeStyle-CssClass="s4-breadcrumbNode" CurrentNodeStyle-CssClass="s4-breadcrumbCurrentNode" RootNodeStyle-CssClass="s4-breadcrumbRootNode" NodeImageOffsetX=0 NodeImageOffsetY=289 NodeImageWidth=16 NodeImageHeight=16 NodeImageUrl="/_layouts/15/images/fgimg.png?rev=44" HideInteriorRootNodes="true" SkipLinkText="" /> </asp:Content>
<asp:Content ContentPlaceHolderId="PlaceHolderPageDescription" runat="server">
	<SharePointWebControls:ProjectProperty Property="Description" runat="server"/>
</asp:Content>
<asp:Content ContentPlaceHolderId="PlaceHolderBodyRightMargin" runat="server">
	<div height=100% class="ms-pagemargin"><IMG SRC="/_layouts/images/blank.gif" width=10 height=1 alt=""></div>
</asp:Content>
<asp:Content ContentPlaceHolderId="PlaceHolderMain" runat="server">
	<!-- Home Page Layout 9/7/2017 -->
	<div class='home-page-layout page-layout clear'>
		<PublishingWebControls:EditModePanel runat="server" CssClass="edit-mode-panel title-edit">
			<SharePointWebControls:TextField runat="server" FieldName="Title"/>
		</PublishingWebControls:EditModePanel>
		<div class="row clear">
			<div class="col-12 col-2-3-m">
				<WebPartPages:WebPartZone runat="server" Title="Image Rotator" ID="ImageRotatorZone"/>
			</div>
			<div class="col-12 col-1-3-m grey-headers">
				<WebPartPages:WebPartZone runat="server" Title="Empty 1" ID="Empty1Zone"/>
			</div>
		</div><!-- end row -->
		<div class="row clear">
			<div class="col-12">
				<WebPartPages:WebPartZone runat="server" Title="Navigation Buttons" ID="NavButtonsZone"/>
			</div>
		</div><!-- end row -->
		<div class="row clear">
			<div class="col-12 col-2-3-m">
				<div class="row clear">
					<div class="col-12 col-1-2-m orange-headers">
						<WebPartPages:WebPartZone runat="server" Title="Announcements" ID="AnnouncementsZone"/>
					</div>
					<div class="col-12 col-1-2-m blue-headers">
						<WebPartPages:WebPartZone runat="server" Title="Events" ID="EventsZone"/>
					</div>
				</div>
				<div class="row clear">
					<div class="col-12 gold-headers">
						<WebPartPages:WebPartZone runat="server" Title="Empty 2" ID="Empty2Zone"/>
					</div>
				</div>
			</div>
			<div class="col-12 col-1-3-m black-headers">
				<WebPartPages:WebPartZone runat="server" Title="Quick Links" ID="QuickLinksZone"/>
			</div>
		</div><!-- end row -->
	</div><!-- end home-page-layout -->
</asp:Content>