module.exports =
    [
        {
            fileName: "demo1.master",
            metadata: {
                "__metadata": { type: "SP.Data.OData__x005f_catalogs_x002f_masterpageItem" },
                Title: "SPS HOUSTON ROCKS",
                ContentTypeId: "0x010105",
                UIVersion: {
                    "__metadata": {
                        "type": "Collection(Edm.String)"
                    },
                    "results": [
                        "15"
                    ]
                }
            }
        }, {
            fileName: "demo2.master",
            metadata: {
                "__metadata": { type: "SP.Data.OData__x005f_catalogs_x002f_masterpageItem" },
                Title: "Test Master Page 2.1",
                ContentTypeId: "0x010105",
                UIVersion: {
                    "__metadata": {
                        "type": "Collection(Edm.String)"
                    },
                    "results": [
                        "15"
                    ]
                }
            }
        },
        {
            fileName: "demo1.aspx",
            metadata: {
                "__metadata": { type: "SP.Data.OData__x005f_catalogs_x002f_masterpageItem" },
                Title: "123123213",
                ContentTypeId: "0x01010007FF3E057FA8AB4AA42FCB67B453FFC100E214EEE741181F4E9F7ACC43278EE81100BFA7E30933CB224692527479B7C52DC0"//,
                //PublishingAssociatedContentType: "Welcome Page, 0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF390064DEA0F50FC8C147B0B6EA0636C4A7D4"
            }
        },
        {
            fileName: 'Item_A_Demo1.html',
            metadata: {
                '__metadata': { type: 'SP.Data.OData__x005f_catalogs_x002f_masterpageItem' },
                Title: 'SPSave Template Test HTML 1111',
                TargetControlType: {
                    '__metadata': {
                        'type': 'Collection(Edm.String)'
                    },
                    'results': [
                        'SearchResults'
                    ]
                },
                ManagedPropertyMapping: `'Title':'Title','Path':'Path','Description':'Description','EditorOWSUSER':'EditorOWSUSER','LastModifiedTime':'LastModifiedTime','CollapsingStatus':'CollapsingStatus','DocId':'DocId','HitHighlightedSummary':'HitHighlightedSummary','HitHighlightedProperties':'HitHighlightedProperties','FileExtension':'FileExtension','ViewsLifeTime':'ViewsLifeTime','ParentLink':'ParentLink','FileType':'FileType','IsContainer':'IsContainer','SecondaryFileExtension':'SecondaryFileExtension','DisplayAuthor':'DisplayAuthor'`,
                ContentTypeId: '0x0101002039C03B61C64EC4A04F5361F3851066030018882C07FBD5AB42A134DD2D514DADCF',
                TemplateHidden: false
            }
        },
        {
            fileName: 'Item_A_Demo_JS.js',
            metadata: {
                '__metadata': { type: 'SP.Data.OData__x005f_catalogs_x002f_masterpageItem' },
                Title: 'SPSave Template Test',
                DisplayTemplateLevel: 'Item',
                TargetControlType: {
                    '__metadata': {
                        'type': 'Collection(Edm.String)'
                    },
                    'results': [
                        'SearchResults'
                    ]
                },
                ManagedPropertyMapping: `'Title':'Title','Path':'Path','Description':'Description'`,
                ContentTypeId: '0x0101002039C03B61C64EC4A04F5361F38510660500A0383064C59087438E649B7323C95AF6',
                TemplateHidden: false
            }
        }
    ]